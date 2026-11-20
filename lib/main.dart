import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineFlix catálogo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      // StreamBuilder escucha si el usuario inició sesión o no
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const CatalogScreen(); // Si hay usuario logueado, va al catálogo
          }
          return const LoginScreen(); // Si no, va al login
        },
      ),
    );
  }
}

// 1. PANTALLA DE INICIO (LOGIN / REGISTRO)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _auth({required bool isRegister}) async {
    setState(() => _isLoading = true);
    try {
      if (isRegister) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie_filter, size: 80, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text('Bienvenido a CineFlix', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => _auth(isRegister: false),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                          child: const Text('Ingresar'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _auth(isRegister: true),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                          child: const Text('Registrarse'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. PANTALLA DE CATÁLOGO
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de películas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Administración',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('peliculas').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No hay películas en el catálogo.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: SizedBox(
                    width: 60, height: 90,
                    child: Image.network(data['urlImagen'] ?? '', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
                  ),
                  title: Text(data['titulo'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('${data['anio']} | ${data['genero']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailScreen(peliculaId: docs[index].id, peliculaData: data)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 3. PANTALLA DE DESCRIPCIÓN (DETALLE)
class DetailScreen extends StatelessWidget {
  final String peliculaId;
  final Map<String, dynamic> peliculaData;
  const DetailScreen({super.key, required this.peliculaId, required this.peliculaData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(peliculaData['titulo'] ?? 'Detalle')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Póster de la película
            SizedBox(
              width: double.infinity, height: 300,
              child: Image.network(peliculaData['urlImagen'] ?? '', fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peliculaData['titulo'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${peliculaData['anio']} | Dirigida por ${peliculaData['director']}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Chip(label: Text(peliculaData['genero'] ?? ''), backgroundColor: Colors.indigo.shade50),
                  const SizedBox(height: 16),
                  const Text('Sinopsis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(peliculaData['sinopsis'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. PANTALLA DE ADMINISTRACIÓN (ALTA/BAJA)
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _tituloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _directorCtrl = TextEditingController();
  final _generoCtrl = TextEditingController();
  final _sinopsisCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  Future<void> _guardarPelicula() async {
    if (_tituloCtrl.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('peliculas').add({
      'titulo': _tituloCtrl.text,
      'anio': _anioCtrl.text,
      'director': _directorCtrl.text,
      'genero': _generoCtrl.text,
      'sinopsis': _sinopsisCtrl.text,
      'urlImagen': _urlCtrl.text,
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Película agregada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Agregar película', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _anioCtrl, decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _directorCtrl, decoration: const InputDecoration(labelText: 'Director', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _generoCtrl, decoration: const InputDecoration(labelText: 'Género', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _sinopsisCtrl, decoration: const InputDecoration(labelText: 'Sinopsis', border: OutlineInputBorder()), maxLines: 3),
          const SizedBox(height: 12),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL de la imagen', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _guardarPelicula,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text('Guardar película'),
          ),
          const Divider(height: 48),
          const Text('Películas en catálogo (para eliminar)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('peliculas').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final docs = snapshot.data!.docs;
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['titulo'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        FirebaseFirestore.instance.collection('peliculas').doc(doc.id).delete();
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}