export type View =
  | { kind: "library" }
  | { kind: "category"; id: string }
  | { kind: "collection"; id: string };
