<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Category;
use App\Models\Transaction;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            // Kategori Pemasukan
            ['name' => 'Gaji Bulanan', 'type' => 'income', 'icon' => 'wallet', 'color' => '#10B981'],
            ['name' => 'Freelance & Proyek', 'type' => 'income', 'icon' => 'laptop', 'color' => '#06B6D4'],
            ['name' => 'Investasi & Dividen', 'type' => 'income', 'icon' => 'trending_up', 'color' => '#8B5CF6'],
            ['name' => 'Bonus / Hadiah', 'type' => 'income', 'icon' => 'gift', 'color' => '#F59E0B'],

            // Kategori Pengeluaran
            ['name' => 'Makanan & Minuman', 'type' => 'expense', 'icon' => 'restaurant', 'color' => '#EF4444'],
            ['name' => 'Transportasi & BBM', 'type' => 'expense', 'icon' => 'car', 'color' => '#F97316'],
            ['name' => 'Tagihan & Utilitas', 'type' => 'expense', 'icon' => 'bolt', 'color' => '#EAB308'],
            ['name' => 'Belanja Bulanan', 'type' => 'expense', 'icon' => 'shopping_bag', 'color' => '#EC4899'],
            ['name' => 'Hiburan & Langganan', 'type' => 'expense', 'icon' => 'movie', 'color' => '#6366F1'],
            ['name' => 'Kesehatan', 'type' => 'expense', 'icon' => 'medical', 'color' => '#14B8A6'],
        ];

        foreach ($categories as $cat) {
            Category::firstOrCreate(
                ['name' => $cat['name'], 'type' => $cat['type']],
                $cat
            );
        }
    }
}
