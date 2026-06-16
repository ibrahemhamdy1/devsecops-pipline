<?php

namespace Database\Seeders;

use App\Models\Task;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Task::factory(20)->create();
        Task::factory(5)->pending()->highPriority()->create();
        Task::factory(3)->done()->create();
    }
}
