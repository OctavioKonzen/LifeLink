import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsService {
  Future<List<Map<String, String>>> fetchMagicNews() async {
    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/sets'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sets = data['data'];
        
        return sets.take(5).map<Map<String, String>>((set) {
          return {
            'title': 'New Set: ${set['name']}',
            'description': 'Release Date: ${set['released_at']}',
            'image': set['icon_svg_uri'] ?? 'https://via.placeholder.com/150',
          };
        }).toList();
      }
    } catch (e) {
      return [
        {'title': 'Error loading news', 'description': 'Check connection', 'image': ''}
      ];
    }
    return [];
  }
}