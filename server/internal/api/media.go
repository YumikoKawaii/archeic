package api

import (
	"context"

	"connectrpc.com/connect"
	archeicv1 "github.com/yumikokawaii/archeic/gen/archeic/v1"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/model"
	"github.com/yumikokawaii/archeic/internal/repository"
	"google.golang.org/protobuf/types/known/timestamppb"
)

var _ archeicv1connect.MediaServiceHandler = (*mediaService)(nil)

type mediaService struct {
	uow   *repository.UnitOfWork
	blobs Blobs
}

func (s *mediaService) List(ctx context.Context, req *connect.Request[archeicv1.MediaServiceListRequest]) (*connect.Response[archeicv1.MediaServiceListResponse], error) {
	items, err := s.uow.Media().List(ctx, model.MediaFilter{
		Kind:         kindFromProto(req.Msg.GetKind()),
		CollectionID: req.Msg.GetCollectionId(),
	})
	if err != nil {
		return nil, repoError("listing media", err)
	}
	out := make([]*archeicv1.Media, 0, len(items))
	for _, m := range items {
		out = append(out, mediaToProto(&m))
	}
	return connect.NewResponse(&archeicv1.MediaServiceListResponse{Media: out}), nil
}

func (s *mediaService) Get(ctx context.Context, req *connect.Request[archeicv1.MediaServiceGetRequest]) (*connect.Response[archeicv1.MediaServiceGetResponse], error) {
	if req.Msg.GetId() == "" {
		return nil, invalid("id is required")
	}
	m, err := s.uow.Media().Get(ctx, req.Msg.GetId())
	if err != nil {
		return nil, repoError("getting media", err)
	}
	return connect.NewResponse(&archeicv1.MediaServiceGetResponse{Media: mediaToProto(m)}), nil
}

func (s *mediaService) Delete(ctx context.Context, req *connect.Request[archeicv1.MediaServiceDeleteRequest]) (*connect.Response[archeicv1.MediaServiceDeleteResponse], error) {
	id := req.Msg.GetId()
	if id == "" {
		return nil, invalid("id is required")
	}
	err := s.uow.Tx(ctx, func(tx *repository.UnitOfWork) error {
		m, err := tx.Media().Get(ctx, id)
		if err != nil {
			return err
		}
		if err := tx.Media().Delete(ctx, id); err != nil {
			return err
		}
		return s.blobs.Remove(ctx, m.ObjectKey)
	})
	if err != nil {
		return nil, repoError("deleting media", err)
	}
	return connect.NewResponse(&archeicv1.MediaServiceDeleteResponse{}), nil
}

func mediaToProto(m *model.Media) *archeicv1.Media {
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
	case model.KindImage:
		return archeicv1.Kind_KIND_IMAGE
	case model.KindVideo:
		return archeicv1.Kind_KIND_VIDEO
	}
	return archeicv1.Kind_KIND_UNSPECIFIED
}

func kindFromProto(k archeicv1.Kind) string {
	switch k {
	case archeicv1.Kind_KIND_IMAGE:
		return model.KindImage
	case archeicv1.Kind_KIND_VIDEO:
		return model.KindVideo
	}
	return ""
}
