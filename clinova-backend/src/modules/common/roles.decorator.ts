import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export type UserRole = Role;

export const ROLES_KEY = 'roles';
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
