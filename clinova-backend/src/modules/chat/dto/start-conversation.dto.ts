import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';

/** Body for POST /chat/conversations/start — value is DoctorProfile.id, not User.id. */
export class StartConversationDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  @MaxLength(128)
  doctorId!: string;
}
