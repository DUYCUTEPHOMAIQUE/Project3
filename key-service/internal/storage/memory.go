package storage

import (
	"key-service/internal/models"
	"sync"
)

type MemoryStorage struct {
	users   map[string]*models.User
	devices map[string]*models.DeviceInfo
	mu      sync.RWMutex
}

func NewMemoryStorage() *MemoryStorage {
	return &MemoryStorage{
		users:   make(map[string]*models.User),
		devices: make(map[string]*models.DeviceInfo),
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

var (
	ErrUserExists     = &StorageError{Message: "Username already exists"}
	ErrUserNotFound   = &StorageError{Message: "User not found"}
	ErrDeviceExists   = &StorageError{Message: "Device already registered"}
	ErrDeviceNotFound = &StorageError{Message: "Device not found"}
)

type StorageError struct {
	Message string
}

func (e *StorageError) Error() string {
	return e.Message
}
