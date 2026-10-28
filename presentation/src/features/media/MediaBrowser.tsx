import { useState, type ReactNode } from "react";
import { addItems, deleteMedia, Kind, moveItem, removeItems, setCover, type Collection, type Media } from "../../api/client";
import { ConfirmButton, EmptyState, Icon, IconButton, PageHeader, Thumb } from "../../components";
import { groupByDay, type Section } from "../../lib/dates";
import { notify, run } from "../../lib/notify";
import CollectionPicker from "../collection/CollectionPicker";
import Viewer from "./Viewer";

interface Props {
  title: string;
  subtitle?: string;
  back?: () => void;
  actions?: ReactNode;
  filters?: ReactNode;
  before?: ReactNode;
  items: Media[];
  collection?: Collection;
  grouped?: boolean;
  empty: { title: string; text: string };
  onChanged: () => void;
}

export default function MediaBrowser(props: Props) {
  const { title, subtitle, back, actions, filters, before, items, collection, grouped, empty, onChanged } = props;
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

  const sections: Section[] = grouped
    ? groupByDay(items)
    : [{ label: "", items: items.map((m, i) => ({ m, i })) }];

  return (
    <section className={selecting ? "page selecting" : "page"}>
      <PageHeader
        title={selecting ? (selected.size ? `${selected.size} selected` : "Select items") : title}
        subtitle={selecting ? undefined : subtitle}
        back={selecting ? undefined : back}
        actions={
          selecting ? (
            <button type="button" className="btn" onClick={stopSelecting}>Done</button>
          ) : (
            <>
              {actions}
              {items.length > 0 && <IconButton icon="select" label="Select" onClick={() => setSelecting(true)} />}
            </>
          )
        }
      >
        {filters && !selecting && <div className="filters">{filters}</div>}
      </PageHeader>

      {before}

      {items.length === 0 ? (
        <EmptyState icon="image" title={empty.title} text={empty.text} />
      ) : (
        sections.map((s) => (
          <section key={s.label || "all"} className="day">
            {s.label && <h3 className="day-label">{s.label}</h3>}
            <div className="grid">
              {s.items.map(({ m, i }) => (
                <button
                  key={m.id}
                  type="button"
                  className={["tile", selected.has(m.id) && "picked", dragFrom === i && "dragging"].filter(Boolean).join(" ")}
                  aria-label={m.name}
                  draggable={!!collection && !selecting}
                  onDragStart={() => setDragFrom(i)}
                  onDragEnd={() => setDragFrom(null)}
                  onDragOver={(e) => collection && e.preventDefault()}
                  onDrop={() => drop(i)}
                  onClick={() => (selecting ? toggle(m.id) : setActive(i))}
                >
                  <Thumb media={m} />
                  <span className="tile-name">{m.name}</span>
                  {m.kind === Kind.VIDEO && <span className="badge"><Icon name="play" size={14} /></span>}
                  {selecting && <i className="check" aria-hidden="true"><Icon name="select" size={22} /></i>}
                </button>
              ))}
            </div>
          </section>
        ))
      )}

      {selecting && (
        <div className="select-bar">
          <button type="button" disabled={!selected.size} onClick={() => setPicking(true)}>
            <Icon name="folderPlus" />
            <span>Add to</span>
          </button>
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
              <Icon name="remove" />
              <span>Remove</span>
            </button>
          )}
          <ConfirmButton
            label="Delete"
            icon="trash"
            disabled={!selected.size}
            onConfirm={() =>
              run(async () => {
                for (const id of ids) await deleteMedia(id);
                done(`Deleted ${ids.length} ${ids.length === 1 ? "file" : "files"}`);
              })
            }
          />
        </div>
      )}

      {active !== null && items[active] && (
        <Viewer
          media={items[active]}
          index={active}
          count={items.length}
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
                aria-label="Set as cover"
                onClick={() =>
                  run(async () => {
                    await setCover(collection.id, items[active].id);
                    notify(`Cover set for ${collection.name}`);
                    onChanged();
                  })
                }
              >
                <Icon name="star" />
                <span>Cover</span>
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
    </section>
  );
}
