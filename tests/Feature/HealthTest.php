<?php

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('health endpoint returns ok', function () {
    $response = $this->getJson('/api/health');

    $response->assertStatus(200)
             ->assertJsonStructure(['status', 'service', 'env', 'version'])
             ->assertJsonPath('status', 'ok');
});

test('detailed health returns checks', function () {
    $response = $this->getJson('/api/health/detailed');

    $response->assertStatus(200)
             ->assertJsonStructure(['status', 'checks'])
             ->assertJsonPath('status', 'ok');
});
