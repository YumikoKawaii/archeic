package api

import (
	"context"
	"fmt"
	"time"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	archeicv1 "github.com/yumikokawaii/archeic/gen/archeic/v1"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/model"
	"github.com/yumikokawaii/archeic/internal/repository"
	"google.golang.org/protobuf/types/known/timestamppb"
)

var _ archeicv1connect.CollectionServiceHandler = (*collectionService)(nil)

type collectionService struct {
	uow *repository.UnitOfWork
}

func (s *collectionService) List(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceListRequest]) (*connect.Response[archeicv1.CollectionServiceListResponse], error) {
	msg := req.Msg
	var (
		items []model.Collection
		err   error
	)
	switch {
	case msg.GetMediaId() != "":
		items, err = s.uow.Collection().ListByMedia(ctx, msg.GetMediaId())
	case msg.GetCategoryId() != "":
		items, err = s.uow.Collection().List(ctx, msg.GetCategoryId(), msg.ParentId)
	default:
		return nil, invalid("category_id or media_id is required")
	}
	if err != nil {
		return nil, repoError("listing collections", err)
	}
	out := make([]*archeicv1.Collection, 0, len(items))
	for _, c := range items {
		out = append(out, collectionToProto(&c))
	}
	return connect.NewResponse(&archeicv1.CollectionServiceListResponse{Collections: out}), nil
}

func (s *collectionService) Get(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceGetRequest]) (*connect.Response[archeicv1.CollectionServiceGetResponse], error) {
	if req.Msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	c, err := s.uow.Collection().Get(ctx, req.Msg.GetId())
	if err != nil {
		return nil, repoError("getting collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceGetResponse{Collection: collectionToProto(c)}), nil
}

func (s *collectionService) Create(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceCreateRequest]) (*connect.Response[archeicv1.CollectionServiceCreateResponse], error) {
	msg := req.Msg
	now := time.Now().UTC()
	c := &model.Collection{
		ID:         uuid.NewString(),
		CategoryID: msg.GetCategoryId(),
		ParentID:   nonEmpty(msg.ParentId),
		Name:       msg.GetName(),
		CoverID:    nonEmpty(msg.CoverId),
		CreatedAt:  now,
		UpdatedAt:  now,
	}
	if c.CategoryID == "" {
		return nil, invalid("category_id is required")
	}
	if c.Name == "" {
		return nil, invalid("name is required")
	}
	err := s.uow.Tx(ctx, func(tx *repository.UnitOfWork) error {
		if err := checkParent(ctx, tx, c); err != nil {
			return err
		}
		return tx.Collection().Create(ctx, c)
	})
	if err != nil {
		return nil, repoError("creating collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceCreateResponse{Collection: collectionToProto(c)}), nil
}

func (s *collectionService) Update(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceUpdateRequest]) (*connect.Response[archeicv1.CollectionServiceUpdateResponse], error) {
	msg := req.Msg
	if msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	if msg.Name != nil && msg.GetName() == "" {
		return nil, invalid("name cannot be empty")
	}
	var c *model.Collection
	err := s.uow.Tx(ctx, func(tx *repository.UnitOfWork) error {
		var err error
		if c, err = tx.Collection().Get(ctx, msg.GetId()); err != nil {
			return err
		}
		if msg.Name != nil {
			c.Name = msg.GetName()
		}
		if msg.ParentId != nil {
			c.ParentID = nonEmpty(msg.ParentId)
		}
		if msg.CoverId != nil {
			c.CoverID = nonEmpty(msg.CoverId)
		}
		if err := checkParent(ctx, tx, c); err != nil {
			return err
		}
		c.UpdatedAt = time.Now().UTC()
		return tx.Collection().Update(ctx, c)
	})
	if err != nil {
		return nil, repoError("updating collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceUpdateResponse{Collection: collectionToProto(c)}), nil
}

func (s *collectionService) Delete(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceDeleteRequest]) (*connect.Response[archeicv1.CollectionServiceDeleteResponse], error) {
	if req.Msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	if err := s.uow.Collection().Delete(ctx, req.Msg.GetId()); err != nil {
		return nil, repoError("deleting collection", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceDeleteResponse{}), nil
}

func (s *collectionService) AddItems(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceAddItemsRequest]) (*connect.Response[archeicv1.CollectionServiceAddItemsResponse], error) {
	msg := req.Msg
	if msg.GetCollectionId() == "" {
		return nil, invalid("collection_id is required")
	}
	err := s.uow.Tx(ctx, func(tx *repository.UnitOfWork) error {
		if _, err := tx.Collection().Get(ctx, msg.GetCollectionId()); err != nil {
			return err
		}
		items, err := tx.Item().LockList(ctx, msg.GetCollectionId())
		if err != nil {
			return err
		}
		last := int32(0)
		if len(items) > 0 {
			last = items[len(items)-1].Position
		}
		for _, id := range msg.GetMediaIds() {
			last += model.PositionGap
			if err := tx.Item().Add(ctx, model.Item{CollectionID: msg.GetCollectionId(), MediaID: id, Position: last}); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, repoError("adding items", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceAddItemsResponse{}), nil
}

func (s *collectionService) RemoveItems(ctx context.Context, req *connect.Request[archeicv1.CollectionServiceRemoveItemsRequest]) (*connect.Response[archeicv1.CollectionServiceRemoveItemsResponse], error) {
	msg := req.Msg
	if msg.GetCollectionId() == "" {
		return nil, invalid("collection_id is required")
	}
	if err := s.uow.Item().Remove(ctx, msg.GetCollectionId(), msg.GetMediaIds()); err != nil {
		return nil, repoError("removing items", err)
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
	err := s.uow.Tx(ctx, func(tx *repository.UnitOfWork) error {
		items, err := tx.Item().LockList(ctx, msg.GetCollectionId())
		if err != nil {
			return err
		}
		changed, ok := items.Move(msg.GetMediaId(), int(msg.GetIndex()))
		if !ok {
			return repository.ErrNotFound
		}
		for _, it := range changed {
			if err := tx.Item().SetPosition(ctx, it); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, repoError("moving item", err)
	}
	return connect.NewResponse(&archeicv1.CollectionServiceMoveItemResponse{}), nil
}

func checkParent(ctx context.Context, tx *repository.UnitOfWork, c *model.Collection) error {
	if c.ParentID == nil {
		return nil
	}
	parent, err := tx.Collection().Get(ctx, *c.ParentID)
	if err != nil {
		return fmt.Errorf("%w: parent %s", repository.ErrInvalidReference, *c.ParentID)
	}
	if parent.CategoryID != c.CategoryID {
		return invalid("parent belongs to another category")
	}
	cycle, err := tx.Collection().InSubtree(ctx, c.ID, parent.ID)
	if err != nil {
		return err
	}
	if cycle {
		return invalid("parent is inside this collection")
	}
	return nil
}

func nonEmpty(s *string) *string {
	if s == nil || *s == "" {
		return nil
	}
	return s
}

func collectionToProto(c *model.Collection) *archeicv1.Collection {
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
