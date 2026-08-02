export const internalDeploymentEnabled = (): boolean =>
  typeof document !== "undefined" &&
  document.documentElement.dataset.internalDeployment === "true";

export const productName = (): string =>
  internalDeploymentEnabled() ? "Lanthos Ops" : "Miru";

export const productHomeUrl = (): string =>
  internalDeploymentEnabled() ? "/" : "https://miru.so/";
