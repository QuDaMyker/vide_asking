-- public.users definition (referenced by foreign keys)
CREATE TABLE IF NOT EXISTS public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- public.photos definition
CREATE TABLE public.photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sender_id uuid NOT NULL,
    photo_url text NOT NULL,
    thumbnail_url text NULL,
    file_size int4 NULL,
    width int4 NULL,
    height int4 NULL,
    mime_type varchar(50) DEFAULT 'image/jpeg'::character varying NULL,
    caption text NULL,
    is_deleted bool DEFAULT false NULL,
    deleted_at timestamp NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    expires_at timestamp NULL,
    "key" varchar(255) NULL,
    CONSTRAINT photos_pkey PRIMARY KEY (id),
    CONSTRAINT photos_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE INDEX idx_photos_created ON public.photos USING btree (created_at);
CREATE INDEX idx_photos_deleted ON public.photos USING btree (is_deleted);
CREATE INDEX idx_photos_sender ON public.photos USING btree (sender_id, created_at);

-- public.reactions definition
CREATE TABLE public.reactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    photo_id uuid NOT NULL,
    user_id uuid NOT NULL,
    emoji varchar(10) NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    CONSTRAINT reactions_pkey PRIMARY KEY (id),
    CONSTRAINT unique_user_photo_reaction UNIQUE (photo_id, user_id),
    CONSTRAINT reactions_photo_id_fkey FOREIGN KEY (photo_id) REFERENCES public.photos(id) ON DELETE CASCADE,
    CONSTRAINT reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE INDEX idx_reactions_photo ON public.reactions USING btree (photo_id);
CREATE INDEX idx_reactions_user ON public.reactions USING btree (user_id);
