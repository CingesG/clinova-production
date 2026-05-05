import {
  Body,
  Controller,
  Get,
  Patch,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  IsEnum,
  MinLength,
  IsOptional,
  IsString,
} from 'class-validator';
import { Role, UserStatus } from '@prisma/client';

import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { AuthGuard } from '../common/auth.guard';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { UsersService } from './users.service';

class ChangeMyPasswordDto {
  @IsString()
  @MinLength(1)
  currentPassword!: string;

  @IsString()
  @MinLength(8)
  newPassword!: string;
}

class UpdateMyProfileDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  /** Display name nick (shown preferentially when set). */
  @IsOptional()
  @IsString()
  nickname?: string;

  /** Legacy JSON key — prefer phoneNumber on new clients. */
  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string | null;

  @IsOptional()
  @IsString()
  dateOfBirth?: string;

  @IsOptional()
  @IsString()
  gender?: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  emergencyContactName?: string;

  @IsOptional()
  @IsString()
  emergencyContactPhone?: string;

  @IsOptional()
  @IsString()
  medicalHistorySummary?: string;
}

class UpdateUserAdminDto {
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsEnum(UserStatus)
  status?: UserStatus;

  @IsOptional()
  @IsString()
  branchId?: string | null;

  @IsOptional()
  @IsString()
  jobTitle?: string | null;

  @IsOptional()
  @IsString()
  @MinLength(8)
  password?: string;
}

@Controller('users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  me(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.me(user.sub);
  }

  @Patch('me/password')
  changeMyPassword(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: ChangeMyPasswordDto,
  ) {
    return this.usersService.changeMyPassword(
      user.sub,
      dto.currentPassword,
      dto.newPassword,
    );
  }

  @Patch('me')
  updateMe(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: UpdateMyProfileDto,
  ) {
    return this.usersService.updateMe(user.sub, dto);
  }

  @Get()
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  list(
    @Query('role') role?: Role,
    @Query('status') status?: UserStatus,
    @Query('branchId') branchId?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.usersService.list({
      role,
      status,
      branchId,
      search,
      page: page ? Number(page) : undefined,
      pageSize: pageSize ? Number(pageSize) : undefined,
    });
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  adminUpdate(@Param('id') id: string, @Body() dto: UpdateUserAdminDto) {
    return this.usersService.adminUpdate(id, dto);
  }
}
