import 'dart:convert'; // <-- Asegúrate que sea 'dart:convert'

// Una clase simple que representa la estructura de tus datos
class User {
  final int id;
  final String username;
  final String email;

  User({
    required this.id,
    required this.username,
    required this.email,
  });

  // Un 'factory constructor' para crear un Usuario desde el JSON (un Map)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
    );
  }
}

// Una función ayudante para convertir el string JSON (que viene de la API)
// en una Lista de objetos User.
List<User> parseUsers(String responseBody) {
  // 1. Decodifica el string JSON en una Lista de Mapas
  final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();

  // 2. Convierte cada Mapa en un objeto User usando el factory
  return parsed.map<User>((json) => User.fromJson(json)).toList();
}{"id":1,"title":"Cashback 20%","subtitle":"A Summer Surprise","image_url":"https://i.etsystatic.com/39867769/r/il/b8513c/4666764553/il_fullxfull.4666764553_a5gm.jpg"}
