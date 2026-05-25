-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table (instead of Users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    name VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Enable RLS on profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create profiles policies
CREATE POLICY "Profiles are viewable by everyone" ON profiles 
    FOR SELECT USING (is_active = true);
CREATE POLICY "Users can update own profile" ON profiles 
    FOR UPDATE USING (auth.uid() = id);

-- Create improved handle_new_user function with error handling
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE 
    display_name TEXT;
BEGIN
    -- Get display name from raw_user_meta_data if available, otherwise use email
    display_name := COALESCE(
        (NEW.raw_user_meta_data->>'full_name'),
        split_part(NEW.email, '@', 1),
        NEW.email
    );
    
    BEGIN
        INSERT INTO public.profiles (id, name)
        VALUES (NEW.id, display_name);
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'Error creating profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
    END;
    
    RETURN NEW;
END;
$$;

-- Create the trigger with proper timing and security
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- Grant necessary permissions
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
GRANT EXECUTE ON FUNCTION handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION handle_new_user() TO service_role;

-- Wallets table
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    circle_wallet_id VARCHAR NOT NULL,
    wallet_type VARCHAR NOT NULL,
    balance DECIMAL(20, 8) NOT NULL DEFAULT 0,
    currency VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Enable RLS on wallets
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- Create wallets policies
CREATE POLICY "Users can view own wallets" ON wallets 
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own wallets" ON wallets 
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own wallets" ON wallets 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Transactions table
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID NOT NULL REFERENCES wallets(id),
    user_id UUID NOT NULL REFERENCES profiles(id),
    circle_transaction_id VARCHAR NOT NULL,
    transaction_type VARCHAR NOT NULL,
    amount DECIMAL(20, 8) NOT NULL,
    currency VARCHAR NOT NULL,
    status VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Enable RLS on transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Create transactions policies
CREATE POLICY "Users can view own transactions" ON transactions 
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own transactions" ON transactions 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Add indexes for foreign keys and frequently queried columns
CREATE INDEX idx_wallets_user_id ON wallets(user_id);
CREATE INDEX idx_transactions_wallet_id ON transactions(wallet_id);
CREATE INDEX idx_transactions_user_id ON transactions(user_id);

-- Add triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wallets_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant additional permissions if needed
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

-- Grant usage of uuid-ossp functions
GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO anon;
GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO authenticated;
GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO service_role;

-- Grant table permissions to authenticated users
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- Disable RLS on all tables
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE wallets DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;

-- Drop policies for profiles
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- Drop policies for wallets
DROP POLICY IF EXISTS "Users can view own wallets" ON wallets;
DROP POLICY IF EXISTS "Users can update own wallets" ON wallets;
DROP POLICY IF EXISTS "Users can insert own wallets" ON wallets;

-- Drop policies for transactions
DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON transactions;

-- Drop storage policies
DROP POLICY IF EXISTS "Give users read access to profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to update their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own profile picture" ON storage.objects;

-- Add comment to describe migration
COMMENT ON TABLE profiles IS 'RLS disabled and policies dropped in migration.';
COMMENT ON TABLE wallets IS 'RLS disabled and policies dropped in migration.';
COMMENT ON TABLE transactions IS 'RLS disabled and policies dropped in migration.';
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- First, we'll create a temporary table to store existing profiles
CREATE TEMP TABLE temp_profiles AS
SELECT *
FROM profiles;
-- Drop dependent foreign keys first
ALTER TABLE wallets DROP CONSTRAINT IF EXISTS wallets_user_id_fkey;
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_user_id_fkey;
-- Drop existing indexes
DROP INDEX IF EXISTS idx_wallets_user_id;
DROP INDEX IF EXISTS idx_transactions_user_id;
-- Drop existing trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();
-- Modify the profiles table
DROP TABLE profiles;
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID NOT NULL REFERENCES auth.users(id),
    name VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(auth_user_id)
);
-- Create the new handle_new_user function before restoring data
CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER SECURITY DEFINER
SET search_path = public LANGUAGE plpgsql AS $$
DECLARE display_name TEXT;
new_profile_id UUID;
BEGIN -- Get display name from raw_user_meta_data if available, otherwise use email
display_name := COALESCE(
    (NEW.raw_user_meta_data->>'full_name'),
    split_part(NEW.email, '@', 1),
    NEW.email
);
BEGIN
INSERT INTO public.profiles (auth_user_id, name)
VALUES (NEW.id, display_name)
RETURNING id INTO new_profile_id;
RAISE LOG 'Created profile % for auth user %',
new_profile_id,
NEW.id;
EXCEPTION
WHEN OTHERS THEN RAISE LOG 'Error creating profile for user %: %',
NEW.id,
SQLERRM;
RETURN NEW;
END;
RETURN NEW;
END;
$$;
-- Create the trigger
CREATE TRIGGER on_auth_user_created
AFTER
INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
-- Restore existing profiles data with proper mapping
INSERT INTO profiles (
        id,
        auth_user_id,
        name,
        created_at,
        updated_at,
        is_active
    )
SELECT uuid_generate_v4(),
    -- Generate new UUID for profile
    id,
    -- Use existing id as auth_user_id
    name,
    created_at,
    updated_at,
    is_active
FROM temp_profiles;
-- Create a temporary table to store the id mappings
CREATE TEMP TABLE id_mappings AS
SELECT old_profiles.id as old_id,
    new_profiles.id as new_id
FROM temp_profiles old_profiles
    JOIN profiles new_profiles ON new_profiles.auth_user_id = old_profiles.id;
-- Update wallets table
ALTER TABLE wallets
    RENAME COLUMN user_id TO profile_id;
-- Update wallets with new profile IDs
UPDATE wallets w
SET profile_id = m.new_id
FROM id_mappings m
WHERE w.profile_id = m.old_id::uuid;
-- Update transactions table
ALTER TABLE transactions
    RENAME COLUMN user_id TO profile_id;
-- Update transactions with new profile IDs
UPDATE transactions t
SET profile_id = m.new_id
FROM id_mappings m
WHERE t.profile_id = m.old_id::uuid;
-- Add new foreign key constraints
ALTER TABLE wallets
ADD CONSTRAINT wallets_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE transactions
ADD CONSTRAINT transactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
-- Recreate indexes with new column names
CREATE INDEX idx_wallets_profile_id ON wallets(profile_id);
CREATE INDEX idx_transactions_profile_id ON transactions(profile_id);

-- Drop temporary tables
DROP TABLE IF EXISTS temp_profiles;
DROP TABLE IF EXISTS id_mappings;
-- Add comments to document the changes
COMMENT ON TABLE profiles IS 'Modified to use its own UUID as primary key with auth_user_id as foreign key to auth.users';
COMMENT ON COLUMN profiles.id IS 'Primary key UUID for the profile';
COMMENT ON COLUMN profiles.auth_user_id IS 'Foreign key reference to auth.users table';
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- Migration Up
ALTER TABLE wallets
    ADD COLUMN wallet_set_id UUID,
    ADD COLUMN wallet_address VARCHAR(255),
    ADD COLUMN account_type VARCHAR(50),
    ADD COLUMN blockchain VARCHAR(50);

CREATE INDEX idx_wallets_address ON wallets(wallet_address);

-- Add comments for clarity
COMMENT ON COLUMN wallets.wallet_set_id IS 'Reference to the wallet set';
COMMENT ON COLUMN wallets.wallet_address IS 'Blockchain wallet address';
COMMENT ON COLUMN wallets.account_type IS 'Type of blockchain account';
COMMENT ON COLUMN wallets.blockchain IS 'Name of the blockchain network';
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- migration_name: enable_realtime_for_transactions
-- description: Enables Realtime for the "transactions" table in the "public" schema

DO $$
BEGIN
  -- Check if the transactions table is already part of the supabase_realtime publication
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'transactions'
  ) THEN
    -- Add the transactions table to the supabase_realtime publication
    ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
    RAISE NOTICE 'Added public.transactions to publication supabase_realtime';
  ELSE
    RAISE NOTICE 'public.transactions is already part of publication supabase_realtime';
  END IF;
END $$;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- migration_name: allow_null_circle_transaction_id
-- description: Allows the "circle_transaction_id" column in the "transactions" table to be nullable.

DO $$
BEGIN
  -- Check if the "circle_transaction_id" column is already nullable
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'circle_transaction_id'
      AND is_nullable = 'NO'
  ) THEN
    -- Alter the "circle_transaction_id" column to allow NULL values
    ALTER TABLE public.transactions
    ALTER COLUMN circle_transaction_id DROP NOT NULL;

    RAISE NOTICE 'Updated "circle_transaction_id" column to allow NULL values';
  ELSE
    RAISE NOTICE '"circle_transaction_id" column is already nullable';
  END IF;
END $$;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- migration_name: enable_realtime_for_wallets
-- description: Enables Realtime for the "wallets" table in the "public" schema

DO $$
BEGIN
  -- Check if the wallets table is already part of the supabase_realtime publication
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'wallets'
  ) THEN
    -- Add the wallets table to the supabase_realtime publication
    ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;
    RAISE NOTICE 'Added public.wallets to publication supabase_realtime';
  ELSE
    RAISE NOTICE 'public.wallets is already part of publication supabase_realtime';
  END IF;
END $$;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- migration_name: add_circle_contract_address_to_transactions
-- description: Adds a "circle_contract_address" column to the "transactions" table in the "public" schema

DO $$
BEGIN
  -- Check if the "circle_contract_address" column already exists
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'circle_contract_address'
  ) THEN
    -- Add the "circle_contract_address" column to the "transactions" table
    ALTER TABLE public.transactions
    ADD COLUMN circle_contract_address VARCHAR;
    RAISE NOTICE 'Added column "circle_contract_address" to table "public.transactions"';
  ELSE
    RAISE NOTICE 'Column "circle_contract_address" already exists in table "public.transactions"';
  END IF;
END $$;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- First, we need to drop the existing unique constraint which includes the foreign key
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_auth_user_id_key;

-- Then drop the foreign key constraint itself
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_auth_user_id_fkey;

-- Add back the foreign key constraint with ON DELETE CASCADE
ALTER TABLE profiles
ADD CONSTRAINT profiles_auth_user_id_fkey 
    FOREIGN KEY (auth_user_id) 
    REFERENCES auth.users(id)
    ON DELETE CASCADE;

-- Re-add the unique constraint
ALTER TABLE profiles
ADD CONSTRAINT profiles_auth_user_id_key 
    UNIQUE (auth_user_id);

-- Add comment to document the change
COMMENT ON CONSTRAINT profiles_auth_user_id_fkey ON profiles IS 'Foreign key reference to auth.users table with CASCADE DELETE enabled';
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

ALTER TABLE profiles ADD COLUMN company_name TEXT;
COMMENT ON COLUMN profiles.company_name IS 'Optional company name for the profile';
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- migration_name: add_email_to_profiles
-- description: Adds a new column "email" to the "profiles" table in the "public" schema

DO $$
BEGIN
  -- Check if the column "email" already exists in the "profiles" table
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'email'
  ) THEN
    -- Add the "email" column to the "profiles" table
    ALTER TABLE public.profiles
    ADD COLUMN email varchar(320);

    RAISE NOTICE 'Added email column to profiles table';
  ELSE
    RAISE NOTICE 'email column already exists in profiles table';
  END IF;
END $$;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- migration_name: add_full_name_to_profiles
-- description: Adds a new column "full_name" to the "profiles" table in the "public" schema
DO $$ BEGIN -- Check if the column "full_name" already exists in the "profiles" table
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
        AND table_name = 'profiles'
        AND column_name = 'full_name'
) THEN -- Add the "full_name" column to the "profiles" table
ALTER TABLE public.profiles
ADD COLUMN full_name varchar(255);
RAISE NOTICE 'Added full_name column to profiles table';
ELSE RAISE NOTICE 'full_name column already exists in profiles table';
END IF;
END $$;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- In Supabase SQL editor:
-- Add passkey_credential column to wallets table
ALTER TABLE wallets
ADD COLUMN passkey_credential TEXT;
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- Use this migration script to add network_id and network_name columns to the transactions table
-- Add network_id column (integer)
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS network_id integer;
-- Add network_name column (varchar)
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS network_name varchar;
-- Set default values for existing records
UPDATE transactions
SET network_id = 80002,
    network_name = 'Polygon Amoy'
WHERE network_id IS NULL;
-- Optional: Add an index on network_id for faster filtering
CREATE INDEX IF NOT EXISTS idx_transactions_network_id ON transactions(network_id);
-- Comment about this migration
COMMENT ON COLUMN transactions.network_id IS 'Network ID for the blockchain (80002 for Polygon Amoy, 421614 for Arbitrum Sepolia)';
COMMENT ON COLUMN transactions.network_name IS 'Human-readable name of the blockchain network';
-- Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- Add username column to the profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS username varchar;

-- Create an index on username for faster lookups (optional)
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- Comment on the username column
COMMENT ON COLUMN public.profiles.username IS 'Unique username identifier for the user';
