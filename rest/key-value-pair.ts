export interface KeyValuePair<T> {
  [key: string]: T;
}

export function isString(value: any) {
  return typeof value === "string" || value instanceof String;
}

export function isObject(value: any) {
  return value && typeof value === "object" && value.constructor === Object;
}
