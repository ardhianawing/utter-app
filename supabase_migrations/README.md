# Database Migrations Guide

## 🚀 How to Run Migration in Supabase

### Option 1: Via Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project: `utter-app-a12ef`

2. **Open SQL Editor**
   - Click **"SQL Editor"** in the left sidebar
   - Click **"+ New query"**

3. **Copy & Paste Migration**
   - Open file: `add_username_column.sql`
   - Copy all content
   - Paste into SQL Editor

4. **Run Migration**
   - Click **"Run"** button (or press Ctrl+Enter)
   - Wait for success message: "Success. No rows returned"

5. **Verify Migration**
   - Run this query to verify:
   ```sql
   SELECT id, name, phone, username, role
   FROM profiles
   ORDER BY created_at;
   ```
   - You should see `username` column with values (same as phone for existing users)

### Option 2: Via Supabase CLI (Advanced)

```bash
# If you have Supabase CLI installed
supabase db push
```

---

## 📋 Migration Details

### What This Migration Does:

1. ✅ **Adds `username` column** to `profiles` table
2. ✅ **Creates index** for faster username lookups
3. ✅ **Populates username** with phone number for existing users (backward compatibility)
4. ✅ **Adds comment** for documentation

### After Migration:

- Existing users can login with **phone number** (as before)
- New users can have **custom usernames**
- Admin can edit username via **User Management** page

---

## 🔧 Troubleshooting

**Error: "column already exists"**
- This is safe, migration is idempotent
- Column already exists, skip to verification

**Error: "permission denied"**
- Make sure you're logged in as project owner
- Check your Supabase project permissions

**No existing users?**
- Step 3 won't affect anything
- You can create users via User Management page after migration

---

## 📝 Next Steps After Migration

1. **Test login** with existing phone numbers
2. **Add new users** with custom usernames
3. **Edit existing users** to add custom usernames
4. **(Optional)** Uncomment unique constraint in migration if you want to enforce unique usernames

---

## ⚠️ Important Notes

- **Backup first**: Supabase auto-backups, but good practice
- **Test in staging**: If you have staging environment
- **Monitor errors**: Check browser console after migration
- **Rollback plan**: Keep old phone-based login as fallback

---

Need help? Contact: ardhianawing@gmail.com
