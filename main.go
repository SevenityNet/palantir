package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/knights-analytics/hugot"

	_ "github.com/joho/godotenv/autoload"
)

func main() {
	session, err := hugot.NewSession()
	if err != nil {
		panic(err)
	}

	defer func() {
		if err := session.Destroy(); err != nil {
			panic(err)
		}
	}()

	modelPath, err := session.DownloadModel("sentence-transformers/all-MiniLM-L6-v2", "./", hugot.NewDownloadOptions())
	if err != nil {
		panic(err)
	}

	config := hugot.FeatureExtractionConfig{
		ModelPath:    modelPath,
		OnnxFilename: "model.onnx",
		Name:         "feature-extractor-embeddings",
	}

	pipeline, err := hugot.NewPipeline(session, config)
	if err != nil {
		panic(err)
	}

	r := gin.Default()
	r.Use(cors())
	r.Use(authenticate())

	r.POST("/embeddings", func(c *gin.Context) {
		batch := []string{}
		if err := c.ShouldBindJSON(&batch); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		batchResult, err := pipeline.RunPipeline(batch)
		if err != nil {
			panic(err)
		}

		c.JSON(http.StatusOK, batchResult.Embeddings)
	})

	r.Run()
}

func cors() gin.HandlerFunc {
	return func(c *gin.Context) {
		corsAllowedOrigin := os.Getenv("CORS_ALLOWED_ORIGINS")

		if corsAllowedOrigin == "*" {
			requestDomain := c.Request.Header.Get("Origin")
			c.Writer.Header().Set("Access-Control-Allow-Origin", requestDomain)
		} else {
			c.Writer.Header().Set("Access-Control-Allow-Origin", corsAllowedOrigin)
		}

		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Baggage, Accept, Sentry-Trace, X-API-KEY")
		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Type")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(200)
			return
		}

		c.Next()
	}
}

func authenticate() gin.HandlerFunc {
	authKey := os.Getenv("AUTH_KEY")
	if authKey == "" {
		log.Println("WARNING: AUTH_KEY is not set. The API is not protected.")
		return func(c *gin.Context) {
			c.Next()
		}
	}

	return func(c *gin.Context) {
		if c.GetHeader("X-API-KEY") != authKey {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			c.Abort()
			return
		}

		c.Next()
	}
}
