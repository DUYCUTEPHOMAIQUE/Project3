package models

type FriendRequest struct {
	RequestID    string  `json:"request_id"`
	FromUserID   string  `json:"from_user_id"`
	FromUsername string  `json:"from_username"`
	FromEmail    *string `json:"from_email,omitempty"`
	ToUserID     string  `json:"to_user_id"`
	ToUsername   string  `json:"to_username"`
	Status       string  `json:"status"` // "pending", "accepted", "rejected"
	CreatedAt    int64   `json:"created_at"`
}

type Friend struct {
	OwnerUserID  string  `json:"owner_user_id"` // User who owns this friendship record
	UserID       string  `json:"user_id"`       // The friend's user ID
	Username     string  `json:"username"`
	Email        *string `json:"email,omitempty"`
	NakamaUserID *string `json:"nakama_user_id,omitempty"` // Nakama user ID for chat
	ChannelID    *string `json:"channel_id,omitempty"`     // Nakama DM channel ID (format: 4.{userId1}.{userId2})
	FriendshipID string  `json:"friendship_id"`
	CreatedAt    int64   `json:"created_at"`
}

type SendFriendRequestRequest struct {
	Username *string `json:"username,omitempty"`
	Email    *string `json:"email,omitempty"`
}

type SendFriendRequestResponse struct {
	RequestID string `json:"request_id"`
	Message   string `json:"message"`
}

type AcceptFriendRequestRequest struct {
	RequestID string `json:"request_id" binding:"required"`
}

type AcceptFriendRequestResponse struct {
	FriendshipID string `json:"friendship_id"`
	Message      string `json:"message"`
}

type FriendRequestsResponse struct {
	Requests []FriendRequest `json:"requests"`
}

type FriendsListResponse struct {
	Friends []Friend `json:"friends"`
}

type RejectFriendRequestRequest struct {
	RequestID string `json:"request_id" binding:"required"`
}

type RejectFriendRequestResponse struct {
	Message string `json:"message"`
}

type RemoveFriendRequest struct {
	FriendUserID string `json:"friend_user_id" binding:"required"`
}

type RemoveFriendResponse struct {
	Message string `json:"message"`
}

type SentFriendRequestsResponse struct {
	Requests []FriendRequest `json:"requests"`
}
