import { useEffect, useState } from "react";
import {
  createCollection,
  deleteCollection,
  getCategory,
  getCollection,
  Kind,
  listCollections,
  listMedia,
  type Category,
  type Collection,
  type Media,
} from "../../api/client";
import CollectionCard from "./CollectionCard";
import { ConfirmButton, NameForm } from "../../components";
import MediaBrowser from "../../features/media/MediaBrowser";
import { notify, run } from "../../lib/notify";
import type { View } from "../../lib/view";

interface Props {
  id: string;
  version: number;
  onNavigate: (v: View) => void;
  onChanged: () => void;
}

export default function CollectionView({ id, version, onNavigate, onChanged }: Props) {
  const [collection, setCollection] = useState<Collection>();
  const [category, setCategory] = useState<Category>();
  const [trail, setTrail] = useState<Collection[]>([]);
  const [children, setChildren] = useState<Collection[]>([]);
  const [items, setItems] = useState<Media[]>([]);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    run(async () => {
      const c = await getCollection(id);
      if (!c) return;
      const parents: Collection[] = [];
      for (let p = c.parentId; p; ) {
        const parent = await getCollection(p);
        if (!parent) break;
        parents.unshift(parent);
        p = parent.parentId;
      }
      setCollection(c);
      setTrail(parents);
      setCategory(await getCategory(c.categoryId));
      setChildren(await listCollections(c.categoryId, c.id));
      setItems(await listMedia(Kind.UNSPECIFIED, c.id));
    });
  }, [id, version]);

  if (!collection) return null;

  const up: View = collection.parentId
    ? { kind: "collection", id: collection.parentId }
    : { kind: "category", id: collection.categoryId };

  return (
    <section className="page">
      <header className="page-head">
        <div>
          <nav className="crumbs" aria-label="Breadcrumb">
            {category && (
              <button type="button" onClick={() => onNavigate({ kind: "category", id: category.id })}>{category.name}</button>
            )}
            {trail.map((p) => (
              <button key={p.id} type="button" onClick={() => onNavigate({ kind: "collection", id: p.id })}>{p.name}</button>
            ))}
          </nav>
          <h2>{collection.name}</h2>
        </div>
        <div className="row">
          <button type="button" onClick={() => setAdding(true)}>New sub-collection</button>
          <ConfirmButton
            label="Delete collection"
            onConfirm={() =>
              run(async () => {
                await deleteCollection(id);
                notify(`Deleted ${collection.name}`);
                onNavigate(up);
                onChanged();
              })
            }
          />
        </div>
      </header>

      {adding && (
        <NameForm
          id="new-sub-collection"
          placeholder="Sub-collection name"
          submit="Create"
          onCancel={() => setAdding(false)}
          onSubmit={(name) =>
            run(async () => {
              await createCollection(collection.categoryId, name, collection.id);
              setAdding(false);
              onChanged();
            })
          }
        />
      )}

      {children.length > 0 && (
        <div className="cards">
          {children.map((c) => (
            <CollectionCard key={c.id} c={c} version={version} onOpen={() => onNavigate({ kind: "collection", id: c.id })} />
          ))}
        </div>
      )}

      <MediaBrowser
        items={items}
        collection={collection}
        onChanged={onChanged}
        empty="This collection is empty. Upload here, or select media in the library and add it."
        toolbar={<span className="count">{items.length} {items.length === 1 ? "item" : "items"} · drag to reorder</span>}
      />
    </section>
  );
}
