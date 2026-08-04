/* eslint-disable */
import React from "react";

import Header from "components/Navbar/Mobile/Header";
import Navigation from "components/Navbar/Mobile/Navigation";
import { useUserContext } from "context/UserContext";
import { internalDeploymentEnabled } from "../../../../lib/internalDeployment";

type WrappedComponentType = React.ComponentType<any>;

const WithLayout =
  (
    WrappedComponent: WrappedComponentType,
    includeNavbar: boolean,
    includeSidebar: boolean
  ) =>
  props => {
    const { selectedTab, setSelectedTab, companyRole } = useUserContext();
    const isInternalDeployment = internalDeploymentEnabled();

    return (
      <div className="h-full">
        {includeNavbar && !isInternalDeployment && (
          <Header selectedTab={selectedTab} />
        )}
        <WrappedComponent {...props} />
        {includeSidebar && !isInternalDeployment && <Navigation />}
      </div>
    );
  };

WithLayout.displayName = "WithLayout";

export default WithLayout;
