import { createClient } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { CategoryService, Layout, type Category } from "../gen/archeic/v1/category_pb";
import { CollectionService, type Collection } from "../gen/archeic/v1/collection_pb";
import { Kind, MediaService, type Media } from "../gen/archeic/v1/media_pb";

export { Kind, Layout };
export type { Category, Collection, Media };

const transport = createConnectTransport({ baseUrl: "/api" });
const media = createClient(MediaService, transport);
const categories = createClient(CategoryService, transport);
const collections = createClient(CollectionService, transport);

export const contentUrl = (id: string) => `/api/media/${id}/content`;

export async function listMedia(kind: Kind = Kind.UNSPECIFIED, collectionId = ""): Promise<Media[]> {
  return (await media.list({ kind, collectionId })).media;
}

export async function uploadMedia(file: File): Promise<string> {
  const body = new FormData();
  body.append("file", file);
  const res = await fetch("/api/media", { method: "POST", body });
  if (!res.ok) throw new Error(await res.text());
  const created: { id: string } = await res.json();
  return created.id;
}

export async function deleteMedia(id: string): Promise<void> {
  await media.delete({ id });
}

export async function listCategories(): Promise<Category[]> {
  return (await categories.list({})).categories;
}

export async function getCategory(id: string): Promise<Category | undefined> {
  return (await categories.get({ id })).category;
}

export async function createCategory(name: string, layout: Layout): Promise<Category | undefined> {
  return (await categories.create({ name, slug: slugify(name), layout })).category;
}

export async function deleteCategory(id: string): Promise<void> {
  await categories.delete({ id });
}

export async function listCollections(categoryId: string, parentId?: string): Promise<Collection[]> {
  return (await collections.list({ categoryId, parentId })).collections;
}

export async function getCollection(id: string): Promise<Collection | undefined> {
  return (await collections.get({ id })).collection;
}

export async function createCollection(categoryId: string, name: string, parentId?: string): Promise<Collection | undefined> {
  return (await collections.create({ categoryId, name, parentId })).collection;
}

export async function setCover(id: string, coverId: string): Promise<void> {
  await collections.update({ id, coverId });
}

export async function deleteCollection(id: string): Promise<void> {
  await collections.delete({ id });
}

export async function addItems(collectionId: string, mediaIds: string[]): Promise<void> {
  await collections.addItems({ collectionId, mediaIds });
}

export async function removeItems(collectionId: string, mediaIds: string[]): Promise<void> {
  await collections.removeItems({ collectionId, mediaIds });
}

export async function moveItem(collectionId: string, mediaId: string, index: number): Promise<void> {
  await collections.moveItem({ collectionId, mediaId, index });
}

export const layoutLabels: [Layout, string][] = [
  [Layout.GALLERY, "Gallery"],
  [Layout.LIBRARY, "Library"],
  [Layout.EPISODIC, "Episodic"],
  [Layout.TIMELINE, "Timeline"],
];

function slugify(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
