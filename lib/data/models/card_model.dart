class CardModel {
  final String id;
  final String name;
  final String imageUrl;
  final String rarity;
  final String colorIdentity;
  final String manaCost;
  final String typeLine;
  final String oracleText;
  final String setName;

  CardModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rarity,
    required this.colorIdentity,
    required this.manaCost,
    required this.typeLine,
    required this.oracleText,
    required this.setName,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    // Lógica para pegar imagem de cartas normais ou de dupla face
    String? img = json['image_uris']?['normal'] ?? 
                 json['card_faces']?[0]['image_uris']?['normal'];

    return CardModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: img ?? '',
      rarity: json['rarity'] ?? '',
      colorIdentity: (json['color_identity'] as List?)?.join('') ?? 'C',
      manaCost: json['mana_cost'] ?? '',
      typeLine: json['type_line'] ?? '',
      oracleText: json['oracle_text'] ?? '',
      setName: json['set_name'] ?? '',
    );
  }
}