export type View =
  | { kind: "library" }
  | { kind: "browse" }
  | { kind: "category"; id: string }
  | { kind: "collection"; id: string };
