import { useState, type ReactNode } from "react";
import { addItems, deleteMedia, moveItem, removeItems, setCover, type Collection, type Media } from "../../api/client";
import CollectionPicker from "../../features/collection/CollectionPicker";
import { ConfirmButton, Thumb } from "../../components";
import { notify, run } from "../../lib/notify";
import Viewer from "./Viewer";

interface Props {
  items: Media[];
  collection?: Collection;
  toolbar?: ReactNode;
  empty: string;
  onChanged: () => void;
}

export default function MediaBrowser({ items, collection, toolbar, empty, onChanged }: Props) {
  const [active, setActive] = useState<number | null>(null);
  const [selecting, setSelecting] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [picking, setPicking] = useState(false);
  const [dragFrom, setDragFrom] = useState<number | null>(null);

  const ids = [...selected];

  const stopSelecting = () => {
    setSelecting(false);
    setSelected(new Set());
  };

  const toggle = (id: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const done = (message: string) => {
    stopSelecting();
    notify(message);
    onChanged();
  };

  const drop = (to: number) => {
    if (!collection || dragFrom === null || dragFrom === to) return;
    const media = items[dragFrom];
    setDragFrom(null);
    run(async () => {
      await moveItem(collection.id, media.id, to);
      onChanged();
    });
  };

  return (
    <>
      <div className="toolbar">
        {selecting ? (
          <>
            <span className="count">{selected.size} selected</span>
            <button type="button" disabled={!selected.size} onClick={() => setPicking(true)}>Add to collection</button>
            {collection && (
              <button
                type="button"
                disabled={!selected.size}
                onClick={() =>
                  run(async () => {
                    await removeItems(collection.id, ids);
                    done(`Removed ${ids.length} from ${collection.name}`);
                  })
                }
              >
                Remove from collection
              </button>
            )}
            {selected.size > 0 && (
              <ConfirmButton
                label="Delete files"
                onConfirm={() =>
                  run(async () => {
                    for (const id of ids) await deleteMedia(id);
                    done(`Deleted ${ids.length} ${ids.length === 1 ? "file" : "files"}`);
                  })
                }
              />
            )}
            <button type="button" onClick={stopSelecting}>Done</button>
          </>
        ) : (
          <>
            <div className="toolbar-main">{toolbar}</div>
            {items.length > 0 && <button type="button" onClick={() => setSelecting(true)}>Select</button>}
          </>
        )}
      </div>

      {items.length === 0 ? (
        <p className="empty">{empty}</p>
      ) : (
        <div className="grid">
          {items.map((m, i) => (
            <button
              key={m.id}
              type="button"
              className={["tile", selected.has(m.id) && "picked", dragFrom === i && "dragging"].filter(Boolean).join(" ")}
              draggable={!!collection && !selecting}
              onDragStart={() => setDragFrom(i)}
              onDragEnd={() => setDragFrom(null)}
              onDragOver={(e) => collection && e.preventDefault()}
              onDrop={() => drop(i)}
              onClick={() => (selecting ? toggle(m.id) : setActive(i))}
            >
              <Thumb media={m} />
              <span>{m.name}</span>
              {selecting && <i className="check" aria-hidden="true" />}
            </button>
          ))}
        </div>
      )}

      {active !== null && items[active] && (
        <Viewer
          media={items[active]}
          onClose={() => setActive(null)}
          onPrev={() => setActive((active - 1 + items.length) % items.length)}
          onNext={() => setActive((active + 1) % items.length)}
          onDelete={() =>
            run(async () => {
              await deleteMedia(items[active].id);
              setActive(null);
              onChanged();
            })
          }
          extra={
            collection && (
              <button
                type="button"
                onClick={() =>
                  run(async () => {
                    await setCover(collection.id, items[active].id);
                    notify(`Cover set for ${collection.name}`);
                    onChanged();
                  })
                }
              >
                Set as cover
              </button>
            )
          }
        />
      )}

      {picking && (
        <CollectionPicker
          count={selected.size}
          onClose={() => setPicking(false)}
          onPick={(c) =>
            run(async () => {
              await addItems(c.id, ids);
              setPicking(false);
              done(`Added ${ids.length} to ${c.name}`);
            })
          }
        />
      )}
    </>
  );
}
