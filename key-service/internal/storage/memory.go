package storage

import (
	"key-service/internal/models"
	"sync"
)

type MemoryStorage struct {
	users          map[string]*models.User
	devices        map[string]*models.DeviceInfo
	friendRequests map[string]*models.FriendRequest // request_id -> FriendRequest
	friendships    map[string]*models.Friend        // friendship_id -> Friend
	mu             sync.RWMutex
}

func NewMemoryStorage() *MemoryStorage {
	return &MemoryStorage{
		users:          make(map[string]*models.User),
		devices:        make(map[string]*models.DeviceInfo),
		friendRequests: make(map[string]*models.FriendRequest),
		friendships:    make(map[string]*models.Friend),
	}
}

func (s *MemoryStorage) CreateUser(user *models.User) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.users[user.Username]; exists {
		return ErrUserExists
	}

	s.users[user.Username] = user
	return nil
}

func (s *MemoryStorage) GetUserByUsername(username string) (*models.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	user, exists := s.users[username]
	if !exists {
		return nil, ErrUserNotFound
	}

	return user, nil
}

func (s *MemoryStorage) GetUserByID(userID string) (*models.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, user := range s.users {
		if user.UserID == userID {
			return user, nil
		}
	}

	return nil, ErrUserNotFound
}

func (s *MemoryStorage) GetUserByEmail(email string) (*models.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, user := range s.users {
		if user.Email != nil && *user.Email == email {
			return user, nil
		}
	}

	return nil, ErrUserNotFound
}

func (s *MemoryStorage) UpdateUser(user *models.User) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.users[user.Username]; !exists {
		return ErrUserNotFound
	}

	s.users[user.Username] = user
	return nil
}

func (s *MemoryStorage) CreateDevice(device *models.DeviceInfo) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.devices[device.DeviceID]; exists {
		return ErrDeviceExists
	}

	s.devices[device.DeviceID] = device
	return nil
}

func (s *MemoryStorage) GetDevice(deviceID string) (*models.DeviceInfo, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	device, exists := s.devices[deviceID]
	if !exists {
		return nil, ErrDeviceNotFound
	}

	return device, nil
}

// GetDevicesByUserID returns all devices for a user
func (s *MemoryStorage) GetDevicesByUserID(userID string) ([]*models.DeviceInfo, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var devices []*models.DeviceInfo
	for _, device := range s.devices {
		if device.UserID == userID {
			devices = append(devices, device)
		}
	}

	if len(devices) == 0 {
		return nil, ErrDeviceNotFound
	}

	return devices, nil
}

func (s *MemoryStorage) DeleteDevice(deviceID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.devices[deviceID]; !exists {
		return ErrDeviceNotFound
	}

	delete(s.devices, deviceID)
	return nil
}

func (s *MemoryStorage) TakeOneTimePrekey(deviceID string) (*models.OneTimePrekeyResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	device, exists := s.devices[deviceID]
	if !exists {
		return nil, ErrDeviceNotFound
	}

	if len(device.OneTimePrekeys) == 0 {
		return nil, nil
	}

	for id, publicKey := range device.OneTimePrekeys {
		delete(device.OneTimePrekeys, id)
		return &models.OneTimePrekeyResponse{
			ID:        id,
			PublicKey: publicKey,
		}, nil
	}

	return nil, nil
}

// Friend request methods
func (s *MemoryStorage) CreateFriendRequest(request *models.FriendRequest) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.friendRequests[request.RequestID]; exists {
		return ErrFriendRequestExists
	}

	s.friendRequests[request.RequestID] = request
	return nil
}

func (s *MemoryStorage) GetFriendRequest(requestID string) (*models.FriendRequest, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	request, exists := s.friendRequests[requestID]
	if !exists {
		return nil, ErrFriendRequestNotFound
	}

	return request, nil
}

func (s *MemoryStorage) GetFriendRequestsForUser(userID string) []*models.FriendRequest {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var requests []*models.FriendRequest
	for _, req := range s.friendRequests {
		if req.ToUserID == userID && req.Status == "pending" {
			requests = append(requests, req)
		}
	}

	return requests
}

func (s *MemoryStorage) GetSentFriendRequestsForUser(userID string) []*models.FriendRequest {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var requests []*models.FriendRequest
	for _, req := range s.friendRequests {
		if req.FromUserID == userID && req.Status == "pending" {
			requests = append(requests, req)
		}
	}

	return requests
}

func (s *MemoryStorage) UpdateFriendRequestStatus(requestID string, status string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	request, exists := s.friendRequests[requestID]
	if !exists {
		return ErrFriendRequestNotFound
	}

	request.Status = status
	return nil
}

// Friend methods
func (s *MemoryStorage) CreateFriendship(friend *models.Friend) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.friendships[friend.FriendshipID]; exists {
		return ErrFriendshipExists
	}

	s.friendships[friend.FriendshipID] = friend
	return nil
}

func (s *MemoryStorage) GetFriendsForUser(userID string) []*models.Friend {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var friends []*models.Friend
	for _, friend := range s.friendships {
		// Only return friendships where this user is the owner
		if friend.OwnerUserID == userID {
			friends = append(friends, friend)
		}
	}

	return friends
}

func (s *MemoryStorage) DeleteFriendship(ownerUserID, friendUserID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Find and delete friendship from owner's perspective
	for friendshipID, friend := range s.friendships {
		if friend.OwnerUserID == ownerUserID && friend.UserID == friendUserID {
			delete(s.friendships, friendshipID)
			return nil
		}
	}

	return ErrFriendshipNotFound
}

func (s *MemoryStorage) AreFriends(userID1, userID2 string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Check if userID1 has userID2 as friend
	for _, friend := range s.friendships {
		if friend.OwnerUserID == userID1 && friend.UserID == userID2 {
			return true
		}
	}

	return false
}

func (s *MemoryStorage) HasPendingRequest(fromUserID, toUserID string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, req := range s.friendRequests {
		if req.FromUserID == fromUserID && req.ToUserID == toUserID && req.Status == "pending" {
			return true
		}
		if req.FromUserID == toUserID && req.ToUserID == fromUserID && req.Status == "pending" {
			return true
		}
	}

	return false
}

var (
	ErrUserExists            = &StorageError{Message: "Username already exists"}
	ErrUserNotFound          = &StorageError{Message: "User not found"}
	ErrDeviceExists          = &StorageError{Message: "Device already registered"}
	ErrDeviceNotFound        = &StorageError{Message: "Device not found"}
	ErrFriendRequestExists   = &StorageError{Message: "Friend request already exists"}
	ErrFriendRequestNotFound = &StorageError{Message: "Friend request not found"}
	ErrFriendshipExists      = &StorageError{Message: "Friendship already exists"}
	ErrFriendshipNotFound    = &StorageError{Message: "Friendship not found"}
)

type StorageError struct {
	Message string
}

func (e *StorageError) Error() string {
	return e.Message
}
