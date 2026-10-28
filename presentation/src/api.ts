import { createClient } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { Kind, MediaService, type Media } from "./gen/archeic/v1/media_pb";

export { Kind };
export type { Media };

const client = createClient(MediaService, createConnectTransport({ baseUrl: "/api" }));

export const contentUrl = (id: string) => `/api/media/${id}/content`;

export async function listMedia(kind: Kind = Kind.UNSPECIFIED): Promise<Media[]> {
  const res = await client.list({ kind });
  return res.media;
}

export async function uploadMedia(file: File): Promise<void> {
  const body = new FormData();
  body.append("file", file);
  const res = await fetch("/api/media", { method: "POST", body });
  if (!res.ok) throw new Error(await res.text());
}

export async function deleteMedia(id: string): Promise<void> {
  await client.delete({ id });
}
