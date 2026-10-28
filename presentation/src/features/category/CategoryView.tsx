import { useEffect, useState } from "react";
import { createCollection, deleteCategory, getCategory, layoutLabels, listCollections, type Category, type Collection } from "../../api/client";
import { ConfirmButton, EmptyState, IconButton, NameForm, PageHeader, Sheet } from "../../components";
import { notify, run } from "../../lib/notify";
import type { View } from "../../lib/view";
import CollectionCard from "../collection/CollectionCard";

interface Props {
  id: string;
  version: number;
  onNavigate: (v: View) => void;
  onChanged: () => void;
}

export default function CategoryView({ id, version, onNavigate, onChanged }: Props) {
  const [category, setCategory] = useState<Category>();
  const [collections, setCollections] = useState<Collection[]>([]);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    run(async () => {
      setCategory(await getCategory(id));
      setCollections(await listCollections(id));
    });
  }, [id, version]);

  if (!category) return null;

  const layout = layoutLabels.find(([l]) => l === category.layout)?.[1] ?? "Gallery";
  const add = () => setAdding(true);

  return (
    <section className="page">
      <PageHeader
        title={category.name}
        subtitle={`${layout} · ${collections.length} ${collections.length === 1 ? "collection" : "collections"}`}
        back={() => onNavigate({ kind: "browse" })}
        actions={
          <>
            <IconButton icon="plus" label="New collection" onClick={add} />
            <ConfirmButton
              label="Delete"
              icon="trash"
              onConfirm={() =>
                run(async () => {
                  await deleteCategory(id);
                  notify(`Deleted ${category.name}`);
                  onNavigate({ kind: "browse" });
                  onChanged();
                })
              }
            />
          </>
        }
      />

      {collections.length === 0 ? (
        <EmptyState
          icon="folderPlus"
          title={`${category.name} is empty`}
          text="Create a collection, then add photos and videos to it."
          action={<button type="button" className="btn primary" onClick={add}>New collection</button>}
        />
      ) : (
        <div className="cards">
          {collections.map((c) => (
            <CollectionCard key={c.id} c={c} version={version} onOpen={() => onNavigate({ kind: "collection", id: c.id })} />
          ))}
        </div>
      )}

      {adding && (
        <Sheet title={`New collection in ${category.name}`} onClose={() => setAdding(false)}>
          <NameForm
            id="new-collection"
            placeholder="Kyoto, Spring 2025"
            submit="Create"
            onCancel={() => setAdding(false)}
            onSubmit={(name) =>
              run(async () => {
                await createCollection(id, name);
                setAdding(false);
                onChanged();
              })
            }
          />
        </Sheet>
      )}
    </section>
  );
}
