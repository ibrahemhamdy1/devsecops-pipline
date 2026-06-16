<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'status'  => 'ok',
            'service' => config('app.name'),
            'env'     => config('app.env'),
            'version' => config('app.version', '1.0.0'),
        ]);
    }

    public function detailed(): JsonResponse
    {
        $checks = [];

        try {
            DB::connection()->getPdo();
            $checks['database'] = ['status' => 'ok'];
        } catch (\Exception $e) {
            $checks['database'] = ['status' => 'error', 'message' => $e->getMessage()];
        }

        try {
            Cache::put('health_check', true, 5);
            $checks['cache'] = Cache::get('health_check')
                ? ['status' => 'ok']
                : ['status' => 'error'];
        } catch (\Exception $e) {
            $checks['cache'] = ['status' => 'error', 'message' => $e->getMessage()];
        }

        $allOk = collect($checks)->every(fn ($c) => $c['status'] === 'ok');

        return response()->json([
            'status' => $allOk ? 'ok' : 'degraded',
            'checks' => $checks,
        ], $allOk ? 200 : 503);
    }
}
