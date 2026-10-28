import { useCallback, useEffect, useState } from "react";
import { contentUrl, deleteMedia, Kind, listMedia, type Media, uploadMedia } from "./api";
import Viewer from "./Viewer";

const filters: [Kind, string][] = [
  [Kind.UNSPECIFIED, "all"],
  [Kind.IMAGE, "image"],
  [Kind.VIDEO, "video"],
];

export default function App() {
  const [items, setItems] = useState<Media[]>([]);
  const [filter, setFilter] = useState<Kind>(Kind.UNSPECIFIED);
  const [active, setActive] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => listMedia(filter).then(setItems), [filter]);

  useEffect(() => {
    load();
  }, [load]);

  const onUpload = async (files: FileList | null) => {
    if (!files) return;
    setBusy(true);
    try {
      for (const f of Array.from(files)) await uploadMedia(f);
      await load();
    } finally {
      setBusy(false);
    }
  };

  const onDelete = async (id: string) => {
    await deleteMedia(id);
    setActive(null);
    await load();
  };

  return (
    <div className="app">
      <header>
        <h1>Archeic</h1>
        <nav>
          {filters.map(([k, label]) => (
            <button key={label} className={filter === k ? "on" : ""} onClick={() => setFilter(k)}>
              {label}
            </button>
          ))}
        </nav>
        <label className="upload">
          {busy ? "Uploading…" : "Upload"}
          <input type="file" multiple accept="image/*,video/*" hidden onChange={(e) => onUpload(e.target.files)} />
        </label>
      </header>

      <main className="grid">
        {items.map((m, i) => (
          <button key={m.id} className="tile" onClick={() => setActive(i)}>
            {m.kind === Kind.IMAGE ? (
              <img src={contentUrl(m.id)} alt={m.name} loading="lazy" />
            ) : (
              <video src={`${contentUrl(m.id)}#t=0.1`} preload="metadata" muted />
            )}
            <span>{m.name}</span>
          </button>
        ))}
      </main>

      {active !== null && items[active] && (
        <Viewer
          media={items[active]}
          onClose={() => setActive(null)}
          onPrev={() => setActive((active - 1 + items.length) % items.length)}
          onNext={() => setActive((active + 1) % items.length)}
          onDelete={() => onDelete(items[active].id)}
        />
      )}
    </div>
  );
}
