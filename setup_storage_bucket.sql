-- Script pour configurer le bucket de stockage des images dans Supabase
-- Exécuter ce script dans l'éditeur SQL de Supabase

-- 1. Créer le bucket 'images' s'il n'existe pas
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'images',
  'images',
  true, -- Bucket public pour permettre l'accès aux images
  5242880, -- Limite de 5MB par fichier
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Politique RLS pour permettre l'upload des images (authentifiés seulement)
CREATE POLICY "Allow authenticated users to upload images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'images' 
  AND auth.role() = 'authenticated'
);

-- 3. Politique RLS pour permettre la lecture des images (public)
CREATE POLICY "Allow public read access to images" ON storage.objects
FOR SELECT USING (bucket_id = 'images');

-- 4. Politique RLS pour permettre la mise à jour des images (authentifiés seulement)
CREATE POLICY "Allow authenticated users to update images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'images' 
  AND auth.role() = 'authenticated'
);

-- 5. Politique RLS pour permettre la suppression des images (authentifiés seulement)
CREATE POLICY "Allow authenticated users to delete images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'images' 
  AND auth.role() = 'authenticated'
);

-- 6. Créer les dossiers pour organiser les images
-- Les dossiers seront créés automatiquement lors du premier upload

-- Note: 
-- - Le bucket 'images' sera utilisé pour stocker toutes les images
-- - Les images des questions de quiz seront dans le dossier 'quiz-questions/'
-- - Les images des règles de Tajweed seront dans le dossier 'tajweed-rules/'
-- - Toutes les images sont publiquement accessibles via leur URL
