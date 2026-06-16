<?php

use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('can list tasks', function () {
    Task::factory(3)->create();

    $this->getJson('/api/tasks')
         ->assertStatus(200)
         ->assertJsonStructure(['data', 'meta', 'links']);
});

test('can create a task', function () {
    $payload = [
        'title'    => 'Test task',
        'status'   => 'pending',
        'priority' => 'high',
    ];

    $this->postJson('/api/tasks', $payload)
         ->assertStatus(201)
         ->assertJsonPath('title', 'Test task')
         ->assertJsonPath('status', 'pending');
});

test('validation rejects invalid status', function () {
    $this->postJson('/api/tasks', [
        'title'    => 'Bad task',
        'status'   => 'invalid_status',
        'priority' => 'high',
    ])->assertStatus(422)
      ->assertJsonValidationErrors(['status']);
});

test('can show a single task', function () {
    $task = Task::factory()->create();

    $this->getJson("/api/tasks/{$task->id}")
         ->assertStatus(200)
         ->assertJsonPath('id', $task->id);
});

test('can update a task', function () {
    $task = Task::factory()->pending()->create();

    $this->putJson("/api/tasks/{$task->id}", ['status' => 'done'])
         ->assertStatus(200)
         ->assertJsonPath('status', 'done');
});

test('can delete a task', function () {
    $task = Task::factory()->create();

    $this->deleteJson("/api/tasks/{$task->id}")
         ->assertStatus(200);

    $this->assertSoftDeleted('tasks', ['id' => $task->id]);
});

test('returns 404 for missing task', function () {
    $this->getJson('/api/tasks/99999')
         ->assertStatus(404);
});

test('can filter tasks by status', function () {
    Task::factory(3)->pending()->create();
    Task::factory(2)->done()->create();

    $this->getJson('/api/tasks?status=pending')
         ->assertStatus(200)
         ->assertJsonCount(3, 'data');
});
