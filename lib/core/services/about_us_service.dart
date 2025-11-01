import 'package:quranic_competition/models/about_us.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AboutUsService {
  final _supabase = Supabase.instance.client;

  /// Récupère les informations "À propos de nous"
  /// Il ne devrait y avoir qu'une seule entrée dans cette table
  Future<AboutUs?> getAboutUs() async {
    try {
      final response = await _supabase
          .from('about_us')
          .select('*')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return AboutUs.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de la récupération de "À propos de nous": $e');
      rethrow;
    }
  }

  /// Crée ou met à jour les informations "À propos de nous"
  /// Si une entrée existe déjà, elle sera mise à jour
  /// Sinon, une nouvelle entrée sera créée
  Future<AboutUs> createOrUpdateAboutUs({
    required String title,
    required String content,
    String? imageUrl,
    String? whatsappUrl,
    String? email,
    String? address,
    String? website,
    String? facebookUrl,
    String? instagramUrl,
    String? youtubeUrl,
  }) async {
    try {
      // Vérifier s'il existe déjà une entrée
      final existing = await _supabase
          .from('about_us')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        // Mettre à jour l'entrée existante
        final response = await _supabase
            .from('about_us')
            .update({
              'title': title,
              'content': content,
              'image_url': imageUrl,
              'whatsapp_url': whatsappUrl,
              'email': email,
              'address': address,
              'website': website,
              'facebook_url': facebookUrl,
              'instagram_url': instagramUrl,
              'youtube_url': youtubeUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'] as String)
            .select()
            .single();

        return AboutUs.fromMap(response);
      } else {
        // Créer une nouvelle entrée
        final response = await _supabase
            .from('about_us')
            .insert({
              'title': title,
              'content': content,
              'image_url': imageUrl,
              'whatsapp_url': whatsappUrl,
              'email': email,
              'address': address,
              'website': website,
              'facebook_url': facebookUrl,
              'instagram_url': instagramUrl,
              'youtube_url': youtubeUrl,
            })
            .select()
            .single();

        return AboutUs.fromMap(response);
      }
    } catch (e) {
      print('❌ Erreur lors de la création/mise à jour de "À propos de nous": $e');
      rethrow;
    }
  }

  /// Supprime les informations "À propos de nous"
  Future<void> deleteAboutUs() async {
    try {
      await _supabase.from('about_us').delete();
    } catch (e) {
      print('❌ Erreur lors de la suppression de "À propos de nous": $e');
      rethrow;
    }
  }
}

