package handlers

import (
	"key-service/internal/models"
	"key-service/internal/storage"
	"key-service/internal/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type FriendHandler struct {
	store *storage.MemoryStorage
}

func NewFriendHandler(store *storage.MemoryStorage) *FriendHandler {
	return &FriendHandler{store: store}
}

// SendFriendRequest sends a friend request to another user
func (h *FriendHandler) SendFriendRequest(c *gin.Context) {
	var req models.SendFriendRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username or email is required"})
		return
	}

	fromUserID, _ := c.Get("user_id")
	fromUsername, _ := c.Get("username")
	fromUserIDStr := fromUserID.(string)
	fromUsernameStr := fromUsername.(string)

	// Find target user by username or email
	var toUser *models.User
	var err error

	if req.Username != nil && *req.Username != "" {
		toUser, err = h.store.GetUserByUsername(*req.Username)
	} else if req.Email != nil && *req.Email != "" {
		toUser, err = h.store.GetUserByEmail(*req.Email)
	} else {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username or email is required"})
		return
	}

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if toUser.UserID == fromUserIDStr {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot send friend request to yourself"})
		return
	}

	// Check if already friends
	if h.store.AreFriends(fromUserIDStr, toUser.UserID) {
		c.JSON(http.StatusConflict, gin.H{"error": "Already friends with this user"})
		return
	}

	// Check if friend request already exists (either sent or received)
	if h.store.HasPendingRequest(fromUserIDStr, toUser.UserID) {
		c.JSON(http.StatusConflict, gin.H{"error": "Friend request already exists"})
		return
	}

	// Create friend request
	requestID := uuid.New().String()
	friendRequest := &models.FriendRequest{
		RequestID:    requestID,
		FromUserID:   fromUserIDStr,
		FromUsername: fromUsernameStr,
		FromEmail:    nil, // Could get from user if needed
		ToUserID:     toUser.UserID,
		ToUsername:   toUser.Username,
		Status:       "pending",
		CreatedAt:    time.Now().Unix(),
	}

	if err := h.store.CreateFriendRequest(friendRequest); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create friend request"})
		return
	}

	c.JSON(http.StatusCreated, models.SendFriendRequestResponse{
		RequestID: requestID,
		Message:   "Friend request sent successfully",
	})
}

// AcceptFriendRequest accepts a pending friend request
func (h *FriendHandler) AcceptFriendRequest(c *gin.Context) {
	var req models.AcceptFriendRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "request_id is required"})
		return
	}

	userID, _ := c.Get("user_id")
	userIDStr := userID.(string)

	// Get friend request
	friendRequest, err := h.store.GetFriendRequest(req.RequestID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friend request not found"})
		return
	}

	// Verify that the request is for the current user
	if friendRequest.ToUserID != userIDStr {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to accept this request"})
		return
	}

	if friendRequest.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Friend request already processed"})
		return
	}

	// Update request status
	if err := h.store.UpdateFriendRequestStatus(req.RequestID, "accepted"); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update friend request"})
		return
	}

	// Create friendship (bidirectional)
	friendshipID1 := uuid.New().String()
	friendshipID2 := uuid.New().String()

	// Get user info
	fromUser, _ := h.store.GetUserByID(friendRequest.FromUserID)
	toUser, _ := h.store.GetUserByID(friendRequest.ToUserID)

	// Generate channel ID if both users have Nakama user IDs
	var channelID *string
	if fromUser.NakamaUserID != nil && toUser.NakamaUserID != nil &&
		*fromUser.NakamaUserID != "" && *toUser.NakamaUserID != "" {
		chID := utils.GenerateNakamaChannelID(*fromUser.NakamaUserID, *toUser.NakamaUserID)
		channelID = &chID
	}

	// Create friendship from requester's perspective (fromUser owns this friendship)
	friend1 := &models.Friend{
		OwnerUserID:  fromUser.UserID,
		UserID:       toUser.UserID,
		Username:     toUser.Username,
		Email:        toUser.Email,
		NakamaUserID: toUser.NakamaUserID,
		ChannelID:    channelID,
		FriendshipID: friendshipID1,
		CreatedAt:    time.Now().Unix(),
	}

	// Create friendship from acceptor's perspective (toUser owns this friendship)
	friend2 := &models.Friend{
		OwnerUserID:  toUser.UserID,
		UserID:       fromUser.UserID,
		Username:     fromUser.Username,
		Email:        fromUser.Email,
		NakamaUserID: fromUser.NakamaUserID,
		ChannelID:    channelID, // Same channel ID for both friends
		FriendshipID: friendshipID2,
		CreatedAt:    time.Now().Unix(),
	}

	// Store both friendships (bidirectional)
	h.store.CreateFriendship(friend1)
	h.store.CreateFriendship(friend2)

	c.JSON(http.StatusOK, models.AcceptFriendRequestResponse{
		FriendshipID: friendshipID1,
		Message:      "Friend request accepted successfully",
	})
}

// GetFriendRequests returns pending friend requests for the current user
func (h *FriendHandler) GetFriendRequests(c *gin.Context) {
	userID, _ := c.Get("user_id")
	userIDStr := userID.(string)

	requests := h.store.GetFriendRequestsForUser(userIDStr)

	// Convert to response format
	responseRequests := make([]models.FriendRequest, len(requests))
	for i, req := range requests {
		responseRequests[i] = *req
	}

	c.JSON(http.StatusOK, models.FriendRequestsResponse{
		Requests: responseRequests,
	})
}

// GetFriends returns the list of friends for the current user
func (h *FriendHandler) GetFriends(c *gin.Context) {
	userID, _ := c.Get("user_id")
	userIDStr := userID.(string)

	friends := h.store.GetFriendsForUser(userIDStr)

	// Convert to response format
	responseFriends := make([]models.Friend, len(friends))
	for i, friend := range friends {
		responseFriends[i] = *friend
	}

	c.JSON(http.StatusOK, models.FriendsListResponse{
		Friends: responseFriends,
	})
}

// RejectFriendRequest rejects a pending friend request
func (h *FriendHandler) RejectFriendRequest(c *gin.Context) {
	var req models.RejectFriendRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "request_id is required"})
		return
	}

	userID, _ := c.Get("user_id")
	userIDStr := userID.(string)

	// Get friend request
	friendRequest, err := h.store.GetFriendRequest(req.RequestID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friend request not found"})
		return
	}

	// Verify that the request is for the current user
	if friendRequest.ToUserID != userIDStr {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to reject this request"})
		return
	}

	if friendRequest.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Friend request already processed"})
		return
	}

	// Update request status
	if err := h.store.UpdateFriendRequestStatus(req.RequestID, "rejected"); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update friend request"})
		return
	}

	c.JSON(http.StatusOK, models.RejectFriendRequestResponse{
		Message: "Friend request rejected successfully",
	})
}

// RemoveFriend removes a friend from the current user's friend list
func (h *FriendHandler) RemoveFriend(c *gin.Context) {
	var req models.RemoveFriendRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "friend_user_id is required"})
		return
	}

	userID, _ := c.Get("user_id")
	userIDStr := userID.(string)

	if req.FriendUserID == userIDStr {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot remove yourself"})
		return
	}

	// Check if they are friends
	if !h.store.AreFriends(userIDStr, req.FriendUserID) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friendship not found"})
		return
	}

	// Delete friendship from both sides
	if err := h.store.DeleteFriendship(userIDStr, req.FriendUserID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove friend"})
		return
	}

	// Also delete the reverse friendship
	h.store.DeleteFriendship(req.FriendUserID, userIDStr)

	c.JSON(http.StatusOK, models.RemoveFriendResponse{
		Message: "Friend removed successfully",
	})
}

// GetSentFriendRequests returns friend requests sent by the current user
func (h *FriendHandler) GetSentFriendRequests(c *gin.Context) {
	userID, _ := c.Get("user_id")
	userIDStr := userID.(string)

	requests := h.store.GetSentFriendRequestsForUser(userIDStr)

	// Convert to response format
	responseRequests := make([]models.FriendRequest, len(requests))
	for i, req := range requests {
		responseRequests[i] = *req
	}

	c.JSON(http.StatusOK, models.SentFriendRequestsResponse{
		Requests: responseRequests,
	})
}
