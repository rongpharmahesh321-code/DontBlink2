import 'package:flutter/material.dart';
import '../widgets/search_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/category_card.dart';
import '../widgets/banner_slider.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String search = "";
  String selectedCategory = "";
  final FirestoreService firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivering to",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            "Diphu, Assam",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SearchBarWidget(
                onChanged: (value) {
                  setState(() {
                    search = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              const BannerSlider(),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      CategoryCard(
                        icon: Icons.local_grocery_store,
                        title: "Groceries",
                        color: Colors.green,
                        isSelected: selectedCategory == "Groceries",
                        onTap: () {
                          setState(() {
                            selectedCategory = selectedCategory == "Groceries"
                                ? ""
                                : "Groceries";
                          });
                        },
                      ),
                      CategoryCard(
                        icon: Icons.fastfood,
                        title: "Snacks",
                        color: Colors.orange,
                        isSelected: selectedCategory == "Snacks",
                        onTap: () {
                          setState(() {
                            selectedCategory = selectedCategory == "Snacks"
                                ? ""
                                : "Snacks";
                          });
                        },
                      ),
                      CategoryCard(
                        icon: Icons.local_drink,
                        title: "Drinks",
                        color: Colors.blue,
                        isSelected: selectedCategory == "Drinks",
                        onTap: () {
                          setState(() {
                            selectedCategory = selectedCategory == "Drinks"
                                ? ""
                                : "Drinks";
                          });
                        },
                      ),
                      CategoryCard(
                        icon: Icons.icecream,
                        title: "Ice Cream",
                        color: Colors.pink,
                        isSelected: selectedCategory == "Ice Cream",
                        onTap: () {
                          setState(() {
                            selectedCategory = selectedCategory == "Ice Cream"
                                ? ""
                                : "Ice Cream";
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Popular Products",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              StreamBuilder<List<Product>>(
                stream: firestoreService.getProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final allProducts = snapshot.data ?? [];

                  final filteredProducts = allProducts.where((product) {
                    final matchesSearch = product.name.toLowerCase().contains(
                      search.toLowerCase(),
                    );

                    final matchesCategory =
                        selectedCategory.isEmpty ||
                        product.category == selectedCategory;

                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          "No products found",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: filteredProducts[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
