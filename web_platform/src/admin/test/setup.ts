import '@testing-library/jest-dom/vitest'
import { afterEach, vi } from 'vitest'
import { cleanup, configure } from '@testing-library/react'
import { setSupabaseForTests } from '../lib/supabase'

// تحت حمل تشغيل الحزمة كاملة بالتوازي تتجاوز بعض الاختبارات مهلة 5 ثوانٍ للاختبار، وتتأخر
// عناصر findBy* عن ثانية الانتظار الافتراضية (وكلها تنجح منفردة). المهل الأطول لا تغير ما يفحص.
vi.setConfig({ testTimeout: 20_000 })
configure({ asyncUtilTimeout: 5_000 })

afterEach(() => {
  cleanup()
  setSupabaseForTests(null)
})
