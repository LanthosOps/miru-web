import React from "react";

import { LanthosMarkSVG, MiruLogoWatermarkSVG } from "miruIcons";
import { internalDeploymentEnabled } from "../../lib/internalDeployment";

const MiruLogoWatermark = () => {
  const isInternalDeployment = internalDeploymentEnabled();

  return (
    <div
      className={`pointer-events-none absolute bottom-0 left-0 z-negative-1 hidden w-2/5 lg:block lg:w-1/6 ${
        isInternalDeployment ? "opacity-10" : ""
      }`}
    >
      <img
        alt=""
        className="w-full object-contain"
        src={isInternalDeployment ? LanthosMarkSVG : MiruLogoWatermarkSVG}
      />
    </div>
  );
};

export default MiruLogoWatermark;
