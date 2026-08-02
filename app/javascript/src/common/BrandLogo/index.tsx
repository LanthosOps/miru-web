import React from "react";

import { LanthosMarkSVG, MiruLogoSVG, MiruLogoWithTextSVG } from "miruIcons";
import { internalDeploymentEnabled } from "../../lib/internalDeployment";

interface BrandLogoProps {
  className?: string;
  compact?: boolean;
  imageClassName?: string;
}

const BrandLogo = ({
  className = "",
  compact = false,
  imageClassName = "h-8 w-auto",
}: BrandLogoProps) => {
  if (internalDeploymentEnabled()) {
    return (
      <span className={`inline-flex items-center gap-2 ${className}`}>
        <img alt="Lanthos" className={imageClassName} src={LanthosMarkSVG} />
        {!compact && (
          <span className="font-semibold tracking-tight text-foreground">
            Lanthos Ops
          </span>
        )}
      </span>
    );
  }

  return (
    <img
      alt="Miru"
      className={`${imageClassName} ${className}`}
      src={compact ? MiruLogoSVG : MiruLogoWithTextSVG}
    />
  );
};

export default BrandLogo;
