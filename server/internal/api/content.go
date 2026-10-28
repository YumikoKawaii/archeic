package api

import (
	"errors"
	"net/http"
	"path"
	"time"

	"github.com/google/uuid"
	"github.com/yumikokawaii/archeic/internal/model"
	"github.com/yumikokawaii/archeic/internal/repository"
	"google.golang.org/protobuf/encoding/protojson"
)

func (s *Server) upload(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	defer file.Close()

	ct := header.Header.Get("Content-Type")
	kind := model.KindOf(ct)
	if kind == "" {
		http.Error(w, "only images and videos are supported", http.StatusUnsupportedMediaType)
		return
	}

	id := uuid.NewString()
	m := &model.Media{
		ID:          id,
		Name:        header.Filename,
		Kind:        kind,
		ContentType: ct,
		Size:        header.Size,
		ObjectKey:   kind + "/" + id + path.Ext(header.Filename),
		CreatedAt:   time.Now().UTC(),
	}
	if err := s.blobs.Put(ctx, m.ObjectKey, file, m.Size, ct); err != nil {
		s.log.ErrorContext(ctx, "upload failed", "err", err)
		http.Error(w, "upload failed", http.StatusInternalServerError)
		return
	}
	if err := s.uow.Media().Create(ctx, m); err != nil {
		_ = s.blobs.Remove(ctx, m.ObjectKey)
		s.log.ErrorContext(ctx, "saving media failed", "err", err)
		http.Error(w, "upload failed", http.StatusInternalServerError)
		return
	}

	body, err := protojson.Marshal(mediaToProto(m))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_, _ = w.Write(body)
}

func (s *Server) content(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	m, err := s.uow.Media().Get(ctx, r.PathValue("id"))
	if errors.Is(err, repository.ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		s.log.ErrorContext(ctx, "getting media failed", "err", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	obj, err := s.blobs.Open(ctx, m.ObjectKey)
	if err != nil {
		s.log.ErrorContext(ctx, "opening object failed", "err", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer obj.Close()
	w.Header().Set("Content-Type", m.ContentType)
	w.Header().Set("Cache-Control", "private, max-age=3600")
	http.ServeContent(w, r, m.Name, m.CreatedAt, obj)
}
