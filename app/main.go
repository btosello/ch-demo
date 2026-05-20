package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics
var (
	activeConnections = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "websocket_active_connections",
		Help: "Number of active WebSocket connections",
	})
	totalConnections = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "websocket_connections_total",
		Help: "Total number of WebSocket connections",
	})
	messagesReceived = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "websocket_messages_received_total",
		Help: "Total number of messages received",
	})
	messagesSent = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "websocket_messages_sent_total",
		Help: "Total number of messages sent",
	})
	messageLatency = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "websocket_message_latency_seconds",
		Help:    "Latency of message processing",
		Buckets: prometheus.DefBuckets,
	})
)

func init() {
	prometheus.MustRegister(activeConnections)
	prometheus.MustRegister(totalConnections)
	prometheus.MustRegister(messagesReceived)
	prometheus.MustRegister(messagesSent)
	prometheus.MustRegister(messageLatency)
}

// Hub maintains the set of active clients and broadcasts messages
type Hub struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

func newHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			h.mu.Lock()
			for client := range h.clients {
				close(client.send)
				delete(h.clients, client)
			}
			h.mu.Unlock()
			return
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			activeConnections.Inc()
			totalConnections.Inc()
			log.Printf("Client connected. Active connections: %d", len(h.clients))
		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()
			activeConnections.Dec()
			log.Printf("Client disconnected. Active connections: %d", len(h.clients))
		case message := <-h.broadcast:
			start := time.Now()
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
					messagesSent.Inc()
				default:
					go func(c *Client) {
						h.unregister <- c
					}(client)
				}
			}
			h.mu.RUnlock()
			messageLatency.Observe(time.Since(start).Seconds())
		}
	}
}

// Client represents a WebSocket client
type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for demo purposes
	},
}

// Message represents a chat message
type Message struct {
	Type      string    `json:"type"`
	Content   string    `json:"content"`
	Sender    string    `json:"sender,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

func (c *Client) readPump(ctx context.Context) {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	
	c.conn.SetReadLimit(512 * 1024) // 512KB max message size
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})
	
	for {
		select {
		case <-ctx.Done():
			return
		default:
			_, message, err := c.conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					log.Printf("WebSocket error: %v", err)
				}
				return
			}
			messagesReceived.Inc()
			
			// Wrap the message with metadata
			msg := Message{
				Type:      "message",
				Content:   string(message),
				Timestamp: time.Now(),
			}
			msgBytes, _ := json.Marshal(msg)
			c.hub.broadcast <- msgBytes
		}
	}
}

func (c *Client) writePump(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second) // Ping interval
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	
	for {
		select {
		case <-ctx.Done():
			c.conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseGoingAway, "Server shutting down"))
			return
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			
			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)
			
			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func serveWs(hub *Hub, ctx context.Context) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("WebSocket upgrade error: %v", err)
			return
		}
		
		client := &Client{
			hub:  hub,
			conn: conn,
			send: make(chan []byte, 256),
		}
		client.hub.register <- client
		
		go client.writePump(ctx)
		go client.readPump(ctx)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	hub := newHub()
	go hub.run(ctx)
	
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", serveWs(hub, ctx))
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ready", readyHandler)
	mux.Handle("/metrics", promhttp.Handler())
	
	// Serve a simple HTML client for testing
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "static/index.html")
	})
	
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	
	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan
		
		log.Println("Received shutdown signal, initiating graceful shutdown...")
		cancel() // Signal all goroutines to stop
		
		// Give connections time to drain
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdownCancel()
		
		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("HTTP server shutdown error: %v", err)
		}
	}()
	
	log.Printf("WebSocket server starting on port %s", port)
	log.Printf("Endpoints: /ws (WebSocket), /health, /ready, /metrics")
	
	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("HTTP server error: %v", err)
	}
	
	log.Println("Server stopped gracefully")
}
