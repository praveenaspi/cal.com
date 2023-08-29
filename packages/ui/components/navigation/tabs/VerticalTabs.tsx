import { useSession } from "next-auth/react";

import { classNames } from "@calcom/lib";
import { UserPermissionRole } from "@calcom/prisma/enums";

import type { VerticalTabItemProps } from "./VerticalTabItem";
import VerticalTabItem from "./VerticalTabItem";

export { VerticalTabItem };

export interface NavTabProps {
  tabs: VerticalTabItemProps[];
  children?: React.ReactNode;
  className?: string;
  sticky?: boolean;
  linkProps?: VerticalTabItemProps["linkProps"];
  itemClassname?: string;
  iconClassName?: string;
}

const NavTabs = function ({
  tabs,
  className = "",
  sticky,
  linkProps,
  itemClassname,
  iconClassName,
  ...props
}: NavTabProps) {
  const session = useSession();

  const currentRole: UserPermissionRole | any = session.data?.user.role || UserPermissionRole.USER;

  return (
    <nav
      className={classNames(
        `no-scrollbar flex flex-col space-y-0.5 overflow-scroll ${className}`,
        sticky && "sticky top-0 -mt-7"
      )}
      aria-label="Tabs"
      {...props}>
      {/* padding top for sticky */}
      {sticky && <div className="pt-6" />}
      {props.children}
      {tabs
        .filter((val) => val.roleAccess?.indexOf(currentRole) != -1)
        .map((tab, idx) => (
          <VerticalTabItem
            {...tab}
            key={idx}
            linkProps={linkProps}
            className={itemClassname}
            iconClassName={iconClassName}
          />
        ))}
    </nav>
  );
};

export default NavTabs;
