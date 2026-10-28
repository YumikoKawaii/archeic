package api

import (
	"context"
	"regexp"
	"time"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	archeicv1 "github.com/yumikokawaii/archeic/gen/archeic/v1"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/model"
	"github.com/yumikokawaii/archeic/internal/repository"
	"google.golang.org/protobuf/types/known/timestamppb"
)

var _ archeicv1connect.CategoryServiceHandler = (*categoryService)(nil)

var slugPattern = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)

type categoryService struct {
	uow *repository.UnitOfWork
}

func (s *categoryService) List(ctx context.Context, _ *connect.Request[archeicv1.CategoryServiceListRequest]) (*connect.Response[archeicv1.CategoryServiceListResponse], error) {
	items, err := s.uow.Category().List(ctx)
	if err != nil {
		return nil, repoError("listing categories", err)
	}
	out := make([]*archeicv1.Category, 0, len(items))
	for _, c := range items {
		out = append(out, categoryToProto(&c))
	}
	return connect.NewResponse(&archeicv1.CategoryServiceListResponse{Categories: out}), nil
}

func (s *categoryService) Get(ctx context.Context, req *connect.Request[archeicv1.CategoryServiceGetRequest]) (*connect.Response[archeicv1.CategoryServiceGetResponse], error) {
	if req.Msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	c, err := s.uow.Category().Get(ctx, req.Msg.GetId())
	if err != nil {
		return nil, repoError("getting category", err)
	}
	return connect.NewResponse(&archeicv1.CategoryServiceGetResponse{Category: categoryToProto(c)}), nil
}

func (s *categoryService) Create(ctx context.Context, req *connect.Request[archeicv1.CategoryServiceCreateRequest]) (*connect.Response[archeicv1.CategoryServiceCreateResponse], error) {
	msg := req.Msg
	now := time.Now().UTC()
	c := &model.Category{
		ID:        uuid.NewString(),
		Slug:      msg.GetSlug(),
		Name:      msg.GetName(),
		Layout:    layoutFromProto(msg.GetLayout()),
		Position:  msg.GetPosition(),
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := validateCategory(c); err != nil {
		return nil, err
	}
	if err := s.uow.Category().Create(ctx, c); err != nil {
		return nil, repoError("creating category", err)
	}
	return connect.NewResponse(&archeicv1.CategoryServiceCreateResponse{Category: categoryToProto(c)}), nil
}

func (s *categoryService) Update(ctx context.Context, req *connect.Request[archeicv1.CategoryServiceUpdateRequest]) (*connect.Response[archeicv1.CategoryServiceUpdateResponse], error) {
	msg := req.Msg
	if msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	var c *model.Category
	err := s.uow.Tx(ctx, func(tx *repository.UnitOfWork) error {
		var err error
		if c, err = tx.Category().Get(ctx, msg.GetId()); err != nil {
			return err
		}
		if msg.Slug != nil {
			c.Slug = msg.GetSlug()
		}
		if msg.Name != nil {
			c.Name = msg.GetName()
		}
		if msg.Layout != nil {
			c.Layout = layoutFromProto(msg.GetLayout())
		}
		if msg.Position != nil {
			c.Position = msg.GetPosition()
		}
		if err := validateCategory(c); err != nil {
			return err
		}
		c.UpdatedAt = time.Now().UTC()
		return tx.Category().Update(ctx, c)
	})
	if err != nil {
		return nil, repoError("updating category", err)
	}
	return connect.NewResponse(&archeicv1.CategoryServiceUpdateResponse{Category: categoryToProto(c)}), nil
}

func (s *categoryService) Delete(ctx context.Context, req *connect.Request[archeicv1.CategoryServiceDeleteRequest]) (*connect.Response[archeicv1.CategoryServiceDeleteResponse], error) {
	if req.Msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	if err := s.uow.Category().Delete(ctx, req.Msg.GetId()); err != nil {
		return nil, repoError("deleting category", err)
	}
	return connect.NewResponse(&archeicv1.CategoryServiceDeleteResponse{}), nil
}

func validateCategory(c *model.Category) error {
	switch {
	case !slugPattern.MatchString(c.Slug):
		return invalid("slug must be lowercase letters, digits and dashes")
	case c.Name == "":
		return invalid("name is required")
	case c.Layout == "":
		return invalid("layout is required")
	}
	return nil
}

func categoryToProto(c *model.Category) *archeicv1.Category {
	return &archeicv1.Category{
		Id:         c.ID,
		Slug:       c.Slug,
		Name:       c.Name,
		Layout:     layoutToProto(c.Layout),
		Position:   c.Position,
		CreateTime: timestamppb.New(c.CreatedAt),
		UpdateTime: timestamppb.New(c.UpdatedAt),
	}
}

var layouts = map[archeicv1.Layout]string{
	archeicv1.Layout_LAYOUT_GALLERY:  model.LayoutGallery,
	archeicv1.Layout_LAYOUT_LIBRARY:  model.LayoutLibrary,
	archeicv1.Layout_LAYOUT_EPISODIC: model.LayoutEpisodic,
	archeicv1.Layout_LAYOUT_TIMELINE: model.LayoutTimeline,
}

func layoutFromProto(l archeicv1.Layout) string {
	return layouts[l]
}

func layoutToProto(l string) archeicv1.Layout {
	for k, v := range layouts {
		if v == l {
			return k
		}
	}
	return archeicv1.Layout_LAYOUT_UNSPECIFIED
}
