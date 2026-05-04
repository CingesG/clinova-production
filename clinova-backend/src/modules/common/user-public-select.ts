/** User fields safe for dashboards / chats (omit password hash, tokens). */
export const USER_PUBLIC_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  email: true,
  phoneNumber: true,
  avatarUrl: true,
  status: true,
} as const;

/** Admin/doctor profile views need more fields — still excludes passwordHash. */
export const USER_DETAIL_ADMIN_SAFE_SELECT = {
  id: true,
  email: true,
  authProvider: true,
  emailVerified: true,
  role: true,
  status: true,
  firstName: true,
  lastName: true,
  nickname: true,
  phoneNumber: true,
  avatarUrl: true,
  branchId: true,
  jobTitle: true,
  createdAt: true,
  updatedAt: true,
} as const;
