package main

import (
	"key-service/internal/handlers"
	"key-service/internal/middleware"
	"key-service/internal/storage"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	if os.Getenv("GIN_MODE") == "" {
		gin.SetMode(gin.ReleaseMode)
	}

	store := storage.NewMemoryStorage()
	authHandler := handlers.NewAuthHandler(store)
	deviceHandler := handlers.NewDeviceHandler(store)
	authMiddleware := middleware.NewAuthMiddleware()

	r := gin.Default()
	r.Use(corsMiddleware())

	api := r.Group("/api/v1")
	{
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.Refresh)
		}

		devices := api.Group("/devices")
		devices.Use(authMiddleware.RequireAuth())
		{
			devices.POST("/register", deviceHandler.Register)
			devices.GET("/:device_id/prekey-bundle", deviceHandler.GetPrekeyBundle)
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r.Run(":" + port)
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
