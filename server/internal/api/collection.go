package api

import (
	"context"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	archeicv1 "github.com/yumikokawaii/archeic/gen/archeic/v1"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/store"
	"google.golang.org/protobuf/types/known/timestamppb"
)

var _ archeicv1connect.CollectionServiceHandler = (*collectionService)(nil)

type collectionService struct {
	repo CollectionRepository
}

func (s *collectionService) List(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceListRequest]) (*connect.Response[archeicv1.CollectionServiceListResponse], error) {
	msg := req.Msg
	if msg.GetCategoryId() == "" {
		return nil, invalid("category_id is required")
	}
	items, err := s.repo.ListCollections(ctx, msg.GetCategoryId(), msg.ParentId)
	if err != nil {
		return nil, storeError("listing collections", err)
	}
	out := make([]*archeicv1.Collection, 0, len(items))
	for _, c := range items {
		out = append(out, collectionToProto(&c))
	}
	return connect.NewResponse(&archeicv1.CollectionServiceListResponse{Collections: out}), nil
}

func (s *collectionService) Get(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceGetRequest]) (*connect.Response[archeicv1.CollectionServiceGetResponse], error) {
	c, err := s.find(ctx, req.Msg.GetId())
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(&archeicv1.CollectionServiceGetResponse{Collection: collectionToProto(c)}), nil
}

func (s *collectionService) Create(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceCreateRequest]) (*connect.Response[archeicv1.CollectionServiceCreateResponse], error) {
	msg := req.Msg
	c := &store.Collection{
		ID:         uuid.NewString(),
		CategoryID: msg.GetCategoryId(),
		ParentID:   nonEmpty(msg.ParentId),
		Name:       msg.GetName(),
		CoverID:    nonEmpty(msg.CoverId),
	}
	if c.CategoryID == "" {
		return nil, invalid("category_id is required")
	}
	if c.Name == "" {
		return nil, invalid("name is required")
	}
	if err := s.repo.CreateCollection(ctx, c); err != nil {
		return nil, storeError("creating collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceCreateResponse{Collection: collectionToProto(c)}), nil
}

func (s *collectionService) Update(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceUpdateRequest]) (*connect.Response[archeicv1.CollectionServiceUpdateResponse], error) {
	msg := req.Msg
	c, err := s.find(ctx, msg.GetId())
	if err != nil {
		return nil, err
	}
	if msg.Name != nil {
		if msg.GetName() == "" {
			return nil, invalid("name cannot be empty")
		}
		c.Name = msg.GetName()
	}
	if msg.ParentId != nil {
		c.ParentID = nonEmpty(msg.ParentId)
	}
	if msg.CoverId != nil {
		c.CoverID = nonEmpty(msg.CoverId)
	}
	if err := s.repo.UpdateCollection(ctx, c); err != nil {
		return nil, storeError("updating collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceUpdateResponse{Collection: collectionToProto(c)}), nil
}

func (s *collectionService) Delete(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceDeleteRequest]) (*connect.Response[archeicv1.CollectionServiceDeleteResponse], error) {
	if req.Msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	if err := s.repo.DeleteCollection(ctx, req.Msg.GetId()); err != nil {
		return nil, storeError("deleting collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceDeleteResponse{}), nil
}

func (s *collectionService) AddItems(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceAddItemsRequest]) (*connect.Response[archeicv1.CollectionServiceAddItemsResponse], error) {
	msg := req.Msg
	if _, err := s.find(ctx, msg.GetCollectionId()); err != nil {
		return nil, err
	}
	if err := s.repo.AddItems(ctx, msg.GetCollectionId(), msg.GetMediaIds()); err != nil {
		return nil, storeError("adding items", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceAddItemsResponse{}), nil
}

func (s *collectionService) RemoveItems(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceRemoveItemsRequest]) (*connect.Response[archeicv1.CollectionServiceRemoveItemsResponse], error) {
	msg := req.Msg
	if msg.GetCollectionId() == "" {
		return nil, invalid("collection_id is required")
	}
	if err := s.repo.RemoveItems(ctx, msg.GetCollectionId(), msg.GetMediaIds()); err != nil {
		return nil, storeError("removing items", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceRemoveItemsResponse{}), nil
}

func (s *collectionService) MoveItem(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceMoveItemRequest]) (*connect.Response[archeicv1.CollectionServiceMoveItemResponse], error) {
	msg := req.Msg
	switch {
	case msg.GetCollectionId() == "":
		return nil, invalid("collection_id is required")
	case msg.GetMediaId() == "":
		return nil, invalid("media_id is required")
	case msg.GetIndex() < 0:
		return nil, invalid("index must not be negative")
	}
	if err := s.repo.MoveItem(ctx, msg.GetCollectionId(), msg.GetMediaId(), int(msg.GetIndex())); err != nil {
		return nil, storeError("moving item", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceMoveItemResponse{}), nil
}

func (s *collectionService) find(ctx context.Context, id string) (*store.Collection, error) {
	if id == "" {
		return nil, invalid("id is required")
	}
	c, err := s.repo.GetCollection(ctx, id)
	if err != nil {
		return nil, storeError("getting collection", err)
	}
	return c, nil
}

func nonEmpty(s *string) *string {
	if s == nil || *s == "" {
		return nil
	}
	return s
}

func collectionToProto(c *store.Collection) *archeicv1.Collection {
	return &archeicv1.Collection{
		Id:         c.ID,
		CategoryId: c.CategoryID,
		ParentId:   c.ParentID,
		Name:       c.Name,
		CoverId:    c.CoverID,
		CreateTime: timestamppb.New(c.CreatedAt),
		UpdateTime: timestamppb.New(c.UpdatedAt),
	}
}
