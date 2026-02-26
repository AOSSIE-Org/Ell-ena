-- Create RPC function to check if user exists by email
CREATE OR REPLACE FUNCTION public.check_user_exists(email_to_check TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users WHERE email = email_to_check
    );
END;
$$;
