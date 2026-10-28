package api

import (
	"context"
	"errors"
	"fmt"

	"connectrpc.com/connect"
	archeicv1 "github.com/yumikokawaii/archeic/gen/archeic/v1"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/store"
	"google.golang.org/protobuf/types/known/timestamppb"
)

var _ archeicv1connect.MediaServiceHandler = (*mediaService)(nil)

type mediaService struct {
	repo  Repository
	blobs Blobs
}

func (s *mediaService) List(ctx context.Context, req *connect.Request[archeicv1.MediaServiceListRequest]) (*connect.Response[archeicv1.MediaServiceListResponse], error) {
	items, err := s.repo.List(ctx, kindFromProto(req.Msg.GetKind()))
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("listing media: %w", err))
	}
	out := make([]*archeicv1.Media, 0, len(items))
	for _, m := range items {
		out = append(out, toProto(&m))
	}
	return connect.NewResponse(&archeicv1.MediaServiceListResponse{Media: out}), nil
}

func (s *mediaService) Get(ctx context.Context, req *connect.Request[archeicv1.MediaServiceGetRequest]) (*connect.Response[archeicv1.MediaServiceGetResponse], error) {
	m, err := s.find(ctx, req.Msg.GetId())
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(&archeicv1.MediaServiceGetResponse{Media: toProto(m)}), nil
}

func (s *mediaService) Delete(ctx context.Context, req *connect.Request[archeicv1.MediaServiceDeleteRequest]) (*connect.Response[archeicv1.MediaServiceDeleteResponse], error) {
	m, err := s.find(ctx, req.Msg.GetId())
	if err != nil {
		return nil, err
	}
	if err := s.blobs.Remove(ctx, m.ObjectKey); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("removing object: %w", err))
	}
	if err := s.repo.Delete(ctx, m.ID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("deleting media: %w", err))
	}
	return connect.NewResponse(&archeicv1.MediaServiceDeleteResponse{}), nil
}

func (s *mediaService) find(ctx context.Context, id string) (*store.Media, error) {
	if id == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("id is required"))
	}
	m, err := s.repo.Get(ctx, id)
	if errors.Is(err, store.ErrNotFound) {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("getting media: %w", err))
	}
	return m, nil
}

func toProto(m *store.Media) *archeicv1.Media {
	return &archeicv1.Media{
		Id:          m.ID,
		Name:        m.Name,
		Kind:        kindToProto(m.Kind),
		ContentType: m.ContentType,
		Size:        m.Size,
		CreateTime:  timestamppb.New(m.CreatedAt),
	}
}

func kindToProto(k string) archeicv1.Kind {
	switch k {
	case store.KindImage:
		return archeicv1.Kind_KIND_IMAGE
	case store.KindVideo:
		return archeicv1.Kind_KIND_VIDEO
	}
	return archeicv1.Kind_KIND_UNSPECIFIED
}

func kindFromProto(k archeicv1.Kind) string {
	switch k {
	case archeicv1.Kind_KIND_IMAGE:
		return store.KindImage
	case archeicv1.Kind_KIND_VIDEO:
		return store.KindVideo
	}
	return ""
}
