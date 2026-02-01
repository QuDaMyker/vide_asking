import { injectable, inject } from 'tsyringe';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../services/database.service';
import { users, User, NewUser } from '../db/schema';

@injectable()
export class UserRepository {
  constructor(
    @inject('DatabaseService') private dbService: DatabaseService,
  ) {}

  async findAll(): Promise<User[]> {
    return await this.dbService.db.select().from(users);
  }

  async findById(id: number): Promise<User | undefined> {
    const result = await this.dbService.db
      .select()
      .from(users)
      .where(eq(users.id, id))
      .limit(1);
    return result[0];
  }

  async findByEmail(email: string): Promise<User | undefined> {
    const result = await this.dbService.db
      .select()
      .from(users)
      .where(eq(users.email, email))
      .limit(1);
    return result[0];
  }

  async create(userData: NewUser): Promise<User> {
    const result = await this.dbService.db
      .insert(users)
      .values(userData)
      .returning();
    return result[0];
  }

  async update(id: number, userData: Partial<NewUser>): Promise<User | undefined> {
    const result = await this.dbService.db
      .update(users)
      .set({ ...userData, updatedAt: new Date() })
      .where(eq(users.id, id))
      .returning();
    return result[0];
  }

  async delete(id: number): Promise<boolean> {
    const result = await this.dbService.db
      .delete(users)
      .where(eq(users.id, id))
      .returning();
    return result.length > 0;
  }
}
