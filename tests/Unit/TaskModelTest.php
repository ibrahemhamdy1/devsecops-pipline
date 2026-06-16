<?php

use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('task is not completed when status is pending', function () {
    $task = Task::factory()->pending()->make();

    expect($task->isCompleted())->toBeFalse();
});

test('task is completed when status is done', function () {
    $task = Task::factory()->done()->make();

    expect($task->isCompleted())->toBeTrue();
});

test('pending scope only returns pending tasks', function () {
    Task::factory(3)->pending()->create();
    Task::factory(2)->done()->create();

    expect(Task::pending()->count())->toBe(3);
});

test('highPriority scope filters correctly', function () {
    Task::factory(2)->highPriority()->create();
    Task::factory(3)->create(['priority' => 'low']);

    expect(Task::highPriority()->count())->toBe(2);
});

test('task has correct fillable attributes', function () {
    $task = new Task();

    expect($task->getFillable())->toContain('title')
        ->toContain('status')
        ->toContain('priority');
});
