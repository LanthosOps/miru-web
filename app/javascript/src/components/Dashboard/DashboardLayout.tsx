import React, { useMemo, useState, useEffect, useRef } from "react";
import { cn } from "../../lib/utils";
import Sidebar from "./Sidebar";
import {
  List,
  X,
  Timer,
  Receipt,
  UsersThree,
  Briefcase,
  Wallet,
  Users,
  ChartLine,
  Calendar,
  Gear,
  Buildings,
  User,
  House,
  CurrencyCircleDollar,
  Tree,
  SignOut,
  Monitor,
} from "phosphor-react";
import { useLocation } from "react-router-dom";
import { useUserContext } from "context/UserContext";
import { logoutApi } from "apis/api";
import { Toastr } from "StyledComponents";
import ThemeToggle from "../../common/ThemeToggle";
import BrandLogo from "common/BrandLogo";
import { hasProAccess } from "../../lib/planAccess";
import { t } from "../../i18n";
import CompactLocaleSwitcher from "../common/CompactLocaleSwitcher";
import TrialBanner from "../common/TrialBanner";
import DashboardTimerControl from "./DashboardTimerControl";
import { clearStoredTimerState } from "../../utils/timeTrackingTimer";

interface DashboardLayoutProps {
  children: React.ReactNode;
  className?: string;
}

const DashboardLayout: React.FC<DashboardLayoutProps> = ({
  children,
  className,
}) => {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const mobileMenuButtonRef = useRef<HTMLButtonElement>(null);
  const mobileSidebarRef = useRef<HTMLDivElement>(null);
  const location = useLocation();
  const { companyRole, user, company, avatarUrl, locale } = useUserContext();
  const isInternalWorkspace = Boolean(company?.internal_deployment);

  const navigationGroups = [
    {
      title: t("sidebar.main"),
      items: [
        {
          label: t("nav.dashboard"),
          href: "/dashboard",
          icon: House,
          roles: ["admin", "owner", "book_keeper"],
        },
        {
          label: t("nav.timeTracking"),
          href: "/time-tracking",
          icon: Timer,
          roles: ["admin", "owner", "employee"],
        },
        {
          label: "Desktop App",
          href: "https://miru.so/features/desktop-app?utm_source=app.miru.so&utm_medium=sidebar&utm_campaign=desktop-app",
          icon: Monitor,
          external: true,
          roles: ["admin", "owner", "book_keeper", "employee", "client"],
        },
        {
          label: t("nav.clients"),
          href: "/clients",
          icon: UsersThree,
          roles: ["admin", "owner"],
        },
        {
          label: t("nav.projects"),
          href: "/projects",
          icon: Briefcase,
          roles: ["admin", "owner", "employee"],
        },
        {
          label: t("nav.team"),
          href: "/team",
          icon: Users,
          roles: ["admin", "owner"],
        },
        {
          label: t("nav.invoices"),
          href: "/invoices",
          icon: Receipt,
          roles: ["admin", "owner", "book_keeper", "client"],
        },
        {
          label: t("nav.payments"),
          href: "/payments",
          icon: Wallet,
          roles: ["admin", "owner", "book_keeper"],
        },
        {
          label: t("nav.reports"),
          href: "/reports",
          icon: ChartLine,
          roles: ["admin", "owner", "book_keeper"],
        },
        {
          label: "Analytics",
          href: "/analytics",
          icon: ChartLine,
          roles: ["admin", "owner", "manager", "book_keeper", "employee"],
        },
        {
          label: t("nav.expenses"),
          href: "/expenses",
          icon: CurrencyCircleDollar,
          roles: ["admin", "owner", "book_keeper", "employee"],
        },
      ],
    },
    {
      title: t("sidebar.organization"),
      items: [
        {
          label: t("sidebar.holidayCalendar"),
          href: "/settings/holidays",
          icon: Calendar,
          roles: ["admin", "owner", "employee"],
        },
        {
          label: t("sidebar.companySettings"),
          href: "/settings/organization",
          icon: Buildings,
          roles: ["admin", "owner"],
        },
        {
          label: t("sidebar.paymentSettings"),
          href: "/settings/payment",
          icon: Wallet,
          roles: ["admin", "owner"],
        },
        {
          label: t("sidebar.billing"),
          href: "/settings/billing",
          icon: Wallet,
          roles: ["admin", "owner"],
        },
      ],
    },
    {
      title: t("sidebar.personalSettings"),
      items: [
        { label: t("sidebar.profile"), href: "/settings/profile", icon: User },
        {
          label: t("settings.labels.preferences"),
          href: "/settings/preferences",
          icon: Gear,
          roles: ["admin", "owner", "book_keeper", "employee"],
        },
        {
          label: t("sidebar.devices"),
          href: "/settings/devices",
          icon: Buildings,
          roles: ["admin", "owner"],
        },
        {
          label: t("sidebar.myLeaves"),
          href: "/settings/leaves",
          icon: Tree,
          roles: ["admin", "owner", "employee"],
        },
        {
          label: t("sidebar.bankTaxInfo"),
          href: "/settings/bank-info",
          icon: CurrencyCircleDollar,
          roles: ["admin", "owner"],
        },
      ],
    },
  ];

  const filterNavigationGroup = group => ({
    ...group,
    items: group.items
      .filter(item => !item.roles || item.roles.includes(companyRole))
      .filter(
        item =>
          !isInternalWorkspace ||
          (item.href !== "/settings/billing" &&
            !item.href.startsWith("https://miru.so/"))
      )
      .map(item =>
        item.href === "/reports" && !hasProAccess(company)
          ? { ...item, href: "/settings/billing?feature=reports" }
          : item
      ),
  });

  // prettier-ignore
  const filteredNavigation = useMemo(
    () => navigationGroups.map(filterNavigationGroup),
    [companyRole, company?.internal_deployment, company?.pro_access, locale]
  );

  const pageTitle = useMemo(() => {
    const item = filteredNavigation
      .flatMap(group => group.items)
      .find(navItem => location.pathname.startsWith(navItem.href));

    return item?.label || t("nav.dashboard");
  }, [location.pathname, filteredNavigation]);

  const handleLogout = async () => {
    try {
      await logoutApi({ skipErrorToast: true });
      clearStoredTimerState();
      window.location.href = "/";
    } catch (error) {
      clearStoredTimerState();
      console.error("Logout failed:", error);
      Toastr.error(t("somethingWentWrong"));
    }
  };

  useEffect(() => {
    if (!mobileOpen) return;

    const sidebar = mobileSidebarRef.current;
    const focusable = Array.from(
      sidebar?.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'
      ) || []
    );
    const firstFocusable = focusable[0];
    const lastFocusable = focusable[focusable.length - 1];

    firstFocusable?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setMobileOpen(false);

        return;
      }

      if (event.key !== "Tab" || focusable.length === 0) return;

      if (event.shiftKey && document.activeElement === firstFocusable) {
        event.preventDefault();
        lastFocusable?.focus();
      } else if (!event.shiftKey && document.activeElement === lastFocusable) {
        event.preventDefault();
        firstFocusable?.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      mobileMenuButtonRef.current?.focus();
    };
  }, [mobileOpen]);
  // prettier-ignore
  const desktopSidebarClasses = cn("hidden transition-all duration-300 lg:fixed lg:inset-y-0 lg:left-0 lg:z-10 lg:block lg:border-r lg:border-border lg:bg-card", sidebarCollapsed ? "lg:w-16" : "lg:w-64");

  return (
    <div
      className={cn(
        "min-h-screen bg-background text-foreground overflow-x-hidden",
        className
      )}
    >
      {mobileOpen && (
        <div
          aria-hidden="true"
          className="fixed inset-0 z-20 bg-black/50 backdrop-blur-sm lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {mobileOpen && (
        <div
          aria-label="Primary navigation"
          aria-modal="true"
          className="mobile-sidebar fixed inset-y-0 left-0 z-30 w-64 lg:hidden"
          id="mobile-navigation"
          ref={mobileSidebarRef}
          role="dialog"
        >
          <div className="h-full border-r border-border bg-card">
            <div className="flex items-center justify-between border-b border-border p-4">
              <div className="flex items-center gap-3">
                <BrandLogo imageClassName="h-7 w-auto" />
              </div>
              <button
                aria-label="Close navigation"
                onClick={() => setMobileOpen(false)}
                className="rounded-md p-2 transition-colors hover:bg-accent"
              >
                <X size={16} weight="light" />
              </button>
            </div>
            <div className="p-4">
              <Sidebar
                navigationGroups={filteredNavigation}
                isCollapsed={false}
                user={{
                  id: user?.id,
                  name:
                    `${user?.first_name || ""} ${
                      user?.last_name || ""
                    }`.trim() ||
                    user?.email ||
                    "User",
                  email: user?.email || "",
                  avatar: avatarUrl || user?.avatar_url || "",
                  currentWorkspaceId: user?.current_workspace_id,
                }}
              />
            </div>
          </div>
        </div>
      )}

      <aside className={desktopSidebarClasses}>
        <Sidebar
          navigationGroups={filteredNavigation}
          isCollapsed={sidebarCollapsed}
          logo={
            <button
              onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
              className="flex w-full items-center gap-3 rounded-lg p-2 transition-colors hover:bg-accent"
              title={
                sidebarCollapsed ? t("sidebar.expand") : t("sidebar.collapse")
              }
            >
              <BrandLogo
                compact={sidebarCollapsed}
                imageClassName="h-7 w-auto shrink-0"
              />
            </button>
          }
          user={{
            id: user?.id,
            name:
              `${user?.first_name || ""} ${user?.last_name || ""}`.trim() ||
              user?.email ||
              "User",
            email: user?.email || "",
            avatar: avatarUrl || user?.avatar_url || "",
            currentWorkspaceId: user?.current_workspace_id,
          }}
        />
      </aside>

      <div
        className={cn(
          "transition-all duration-300 min-w-0 overflow-x-hidden",
          sidebarCollapsed ? "lg:ml-16" : "lg:ml-64"
        )}
      >
        <header className="sticky top-0 z-10 border-b border-border bg-background/90 backdrop-blur">
          <div className="flex items-center justify-between gap-3 px-3 py-3 sm:px-4 sm:py-4 md:px-6 lg:px-8">
            <div className="flex items-center gap-3 min-w-0">
              <button
                aria-controls="mobile-navigation"
                aria-expanded={mobileOpen}
                aria-label="Open navigation"
                onClick={() => setMobileOpen(true)}
                ref={mobileMenuButtonRef}
                className="rounded-lg border border-border bg-card p-2.5 shadow-sm transition-colors hover:bg-accent lg:hidden shrink-0"
              >
                <List size={20} weight="light" />
              </button>
              <h1 className="text-base sm:text-lg font-semibold text-foreground lg:text-xl truncate">
                {pageTitle}
              </h1>
            </div>
            <div className="flex items-center gap-1.5 sm:gap-2 shrink-0">
              <div className="hidden md:block">
                <DashboardTimerControl />
              </div>
              <CompactLocaleSwitcher />
              <ThemeToggle compact />
              <button
                type="button"
                aria-label={t("nav.logout")}
                onClick={handleLogout}
                className="inline-flex items-center rounded-lg border border-border bg-card p-2 sm:px-3 sm:py-2 text-sm text-foreground transition hover:bg-accent"
              >
                <SignOut size={16} aria-hidden="true" />
              </button>
            </div>
          </div>
        </header>

        <main className="px-4 pb-8 pt-4 lg:px-8 w-full min-w-0 overflow-x-hidden">
          <TrialBanner />
          {children}
        </main>
      </div>
    </div>
  );
};

export default DashboardLayout;
