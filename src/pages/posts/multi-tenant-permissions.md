---
layout: ../../layouts/PostLayout.astro
title: 當一個用戶同時屬於三個租戶
date: 2026-01-13T12:16
description: 設計三層權限模型，解決用戶同時屬於多個租戶的權限管理問題
tags:
  - Multi-Tenant
  - 權限設計
  - PostgreSQL
  - Supabase
---

「這個用戶是 admin，所以他可以看到所有課程。」

這是我一開始的權限設計。

users 表加一個 role 欄位，值是 `admin`、`member`、`guest` 之一。
API 裡面判斷 `if (user.role === 'admin')` 就放行。

簡單、直覺、快速。

然後問題來了。

---

## 先講一下什麼是 Multi-Tenant

如果你沒碰過這個詞，可以想像成「一個系統裡面有很多房東」。

像 Notion、Slack、Shopify 這些 SaaS 產品，每個公司或團隊都有自己的「空間」。
Notion 裡面你的 workspace 跟我的 workspace 是分開的，你看不到我的筆記，我也看不到你的。

這個「空間」就是租戶（Tenant）。

Multi-Tenant 就是「一套系統服務多個租戶」。
所有租戶共用同一套程式碼、同一個資料庫，但資料是隔離的。

我在做的是線上課程平台。
每個講師有自己的「學院」——自己的課程、自己的學生、自己的訂單。
這些學院就是租戶。

好，背景講完了。

---

## 義大利麵是怎麼長出來的

講師 Jeff 在自己的租戶是 admin，他可以管理課程、查看訂單、設定價格。
沒問題。

但 Jeff 同時也是講師 Alice 那邊的學生——他買了 Alice 的課。

這時候 Jeff 的 role 是什麼？

`admin`？
那他不就可以看到 Alice 的後台了？

`member`？
那他自己的租戶怎麼管理？

我試著加一個 `current_tenant_id` 欄位來追蹤「用戶目前在哪個租戶」，然後根據這個切換權限。

結果 code 變成這樣：

```typescript
function canEditCourse(user, course) {
  if (user.role === 'admin' && user.current_tenant_id === course.tenant_id) {
    return true;
  }
  if (user.role === 'super_admin') {
    return true;
  }
  if (user.id === course.creator_id) {
    return true;
  }
  // 還有十幾個 if...
}
```

每次加新功能，就要回來改這個函數。
每次有 bug，就要花半小時 debug 這坨義大利麵。

**義大利麵不是一開始就是義大利麵的。**

它是這樣長出來的：

1. 一開始只有一個 `if`，很乾淨
2. 需求來了，加一個 `if`
3. 邊界情況，再加一個 `if`
4. 例外處理，又加一個 `if`
5. 半年後回頭看，已經認不出來了

問題出在哪？

**我把「這個人是誰」跟「這個人在這裡能幹嘛」混在一起了。**

Jeff 是 Jeff，這件事不會變。
但 Jeff 在自己學院是老闆，在 Alice 學院是學生——這是「關係」，不是「身份」。

我意識到根本問題：**權限不應該綁在 user 身上，應該綁在「user 和 tenant 的關係」上。**

---

## 三層權限模型

踩完坑之後，我重新設計了權限架構。分成三層：

```
┌─────────────────────────────────────┐
│      第一層：認證（Authentication）  │
│      這個人是誰？有沒有登入？         │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│      第二層：租戶歸屬（Tenant Access）│
│      這個人屬於哪些租戶？角色是什麼？  │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│      第三層：資源權限（Resource ACL） │
│      這個人對這個資源有什麼權限？      │
└─────────────────────────────────────┘
```

每一層負責不同的事：

**第一層：認證**

最基本的。
用戶有沒有登入？token 有沒有過期？
[Supabase](https://supabase.com/) Auth 幫我處理這層。

**第二層：租戶歸屬**

這個用戶屬於哪些租戶？在每個租戶裡的角色是什麼？
這是多租戶權限的核心，待會詳細講。

**第三層：資源權限**

針對特定資源的細粒度權限。
例如：這個用戶可以編輯這堂課嗎？可以看到這張訂單嗎？

三層分開，邏輯就清楚了。

---

## 那張關鍵的中間表

解決「用戶同時屬於多個租戶」的關鍵是這張表：

```sql
CREATE TABLE user_tenant_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- 同一個用戶在同一個租戶只能有一筆記錄
  UNIQUE(user_id, tenant_id)
);

-- 加索引，查詢會很頻繁
CREATE INDEX idx_uta_user ON user_tenant_access(user_id);
CREATE INDEX idx_uta_tenant ON user_tenant_access(tenant_id);
CREATE INDEX idx_uta_user_tenant ON user_tenant_access(user_id, tenant_id);
```

現在 Jeff 的權限變成這樣：

```
user_tenant_access 表：
┌──────────┬────────────────┬────────────────┬─────────┐
│ id       │ user_id        │ tenant_id      │ role    │
├──────────┼────────────────┼────────────────┼─────────┤
│ 1        │ jeff           │ jeff_academy   │ owner   │  ← Jeff 是自己學院的 owner
│ 2        │ jeff           │ alice_academy  │ member  │  ← Jeff 是 Alice 學院的學生
│ 3        │ jeff           │ bob_academy    │ admin   │  ← Jeff 是 Bob 學院的管理員
└──────────┴────────────────┴────────────────┴─────────┘
```

一個用戶，三個租戶，三種不同的角色。

查詢也變簡單了：

```typescript
// 取得用戶在特定租戶的角色
async function getUserTenantRole(userId: string, tenantId: string) {
  const { data } = await supabase
    .from('user_tenant_access')
    .select('role')
    .eq('user_id', userId)
    .eq('tenant_id', tenantId)
    .single();

  return data?.role ?? null;
}

// 取得用戶所有的租戶
async function getUserTenants(userId: string) {
  const { data } = await supabase
    .from('user_tenant_access')
    .select(`
      role,
      tenant:tenants(id, name, slug, logo_url)
    `)
    .eq('user_id', userId);

  return data ?? [];
}
```

---

## 角色不要設計太多

我只用三個：

| 角色 | 說明 | 典型權限 |
|------|------|----------|
| **owner** | 租戶擁有者 | 所有權限，包含刪除租戶、轉移擁有權 |
| **admin** | 管理員 | 管理課程、訂單、用戶，但不能刪除租戶 |
| **member** | 一般成員 | 查看已購買的內容，不能管理後台 |

為什麼分 owner 和 admin？

因為有些操作只有擁有者能做：

- 刪除整個租戶
- 把擁有權轉讓給別人
- 修改計費資訊
- 管理其他 admin

如果 admin 可以把另一個 admin 踢掉，那 owner 請人幫忙管理的時候，可能反過來被踢走。
這種事真的會發生。

角色的權限定義：

```typescript
const ROLE_PERMISSIONS = {
  owner: [
    'tenant:delete',
    'tenant:transfer',
    'tenant:billing',
    'admin:manage',
    'course:*',
    'order:*',
    'user:*',
    'settings:*',
  ],
  admin: [
    'course:*',
    'order:*',
    'user:view',
    'user:invite',
    'settings:view',
    'settings:edit',
  ],
  member: [
    'course:view_purchased',
    'order:view_own',
    'profile:edit',
  ],
} as const;

function hasPermission(role: string, permission: string): boolean {
  const permissions = ROLE_PERMISSIONS[role] ?? [];

  return permissions.some(p => {
    if (p === permission) return true;
    if (p.endsWith(':*')) {
      const prefix = p.slice(0, -1); // 'course:*' -> 'course:'
      return permission.startsWith(prefix);
    }
    return false;
  });
}
```

用法：

```typescript
const role = await getUserTenantRole(userId, tenantId);

if (!role) {
  throw new Error('用戶不屬於此租戶');
}

if (!hasPermission(role, 'course:edit')) {
  throw new Error('沒有編輯課程的權限');
}
```

---

## 這個用戶可以看這堂課嗎

第三層是針對特定資源的權限。

例如「這個用戶可以看這堂課嗎」，不只看角色，還要看其他條件：

```typescript
interface CourseAccessResult {
  canView: boolean;
  canEdit: boolean;
  canDelete: boolean;
  reason?: string;
}

async function canAccessCourse(
  userId: string,
  courseId: string
): Promise<CourseAccessResult> {
  // 1. 取得課程資訊
  const { data: course } = await supabase
    .from('courses')
    .select('id, tenant_id, status, creator_id')
    .eq('id', courseId)
    .single();

  if (!course) {
    return { canView: false, canEdit: false, canDelete: false, reason: '課程不存在' };
  }

  // 2. 取得用戶在這個租戶的角色
  const role = await getUserTenantRole(userId, course.tenant_id);

  // 不屬於這個租戶
  if (!role) {
    return { canView: false, canEdit: false, canDelete: false, reason: '無權存取此租戶' };
  }

  // 3. owner 和 admin 有完整權限
  if (role === 'owner' || role === 'admin') {
    return { canView: true, canEdit: true, canDelete: role === 'owner' };
  }

  // 4. member 要檢查是否購買
  if (role === 'member') {
    // 公開課程可以看
    if (course.status === 'public') {
      return { canView: true, canEdit: false, canDelete: false };
    }

    // 檢查是否有購買記錄
    const { data: enrollment } = await supabase
      .from('enrollments')
      .select('id')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .single();

    if (enrollment) {
      return { canView: true, canEdit: false, canDelete: false };
    }

    return { canView: false, canEdit: false, canDelete: false, reason: '尚未購買此課程' };
  }

  return { canView: false, canEdit: false, canDelete: false, reason: '未知角色' };
}
```

API 裡面這樣用：

```typescript
// app/api/courses/[id]/route.ts
export async function GET(request: Request, { params }: { params: { id: string } }) {
  const user = await getUser(request);

  const access = await canAccessCourse(user.id, params.id);

  if (!access.canView) {
    return NextResponse.json({ error: access.reason }, { status: 403 });
  }

  // 繼續處理...
}
```

邏輯很清楚，而且每個決策點都可以追蹤。

---

## 跟 RLS 的搭配

這套權限設計要配合 [Supabase](https://supabase.com/) 的 [RLS](/posts/supabase-rls-multi-tenant) 才完整。

應用層（TypeScript）負責**商業邏輯**的權限判斷：這個用戶可不可以編輯這堂課？可不可以退款？

資料庫層（RLS）負責**資料隔離**的最後防線：就算應用層出 bug，資料也不會洩漏到其他租戶。

RLS 政策會用到 `user_tenant_access` 表：

```sql
-- 課程表的 RLS：只能看到自己所屬租戶的課程
CREATE POLICY "Users can view courses in their tenants" ON courses
  FOR SELECT
  USING (
    tenant_id IN (
      SELECT tenant_id
      FROM user_tenant_access
      WHERE user_id = auth.uid()
    )
  );

-- 編輯權限：只有 owner 和 admin 可以
CREATE POLICY "Admins can update courses" ON courses
  FOR UPDATE
  USING (
    tenant_id IN (
      SELECT tenant_id
      FROM user_tenant_access
      WHERE user_id = auth.uid()
      AND role IN ('owner', 'admin')
    )
  );

-- 刪除權限：只有 owner 可以
CREATE POLICY "Owners can delete courses" ON courses
  FOR DELETE
  USING (
    tenant_id IN (
      SELECT tenant_id
      FROM user_tenant_access
      WHERE user_id = auth.uid()
      AND role = 'owner'
    )
  );
```

兩層防護：

1. **應用層**：精細的商業邏輯判斷，提供友善的錯誤訊息
2. **資料庫層**：最後防線，就算 code 有 bug 也不會洩漏資料

這就是我在[第二篇](/posts/supabase-rls-multi-tenant)說的「深度防禦」。

---

## 實用的輔助函數

日常開發會用到這些函數：

```typescript
// lib/permissions.ts

/**
 * 確保用戶屬於租戶，否則拋出錯誤
 */
export async function requireTenantAccess(
  userId: string,
  tenantId: string
): Promise<string> {
  const role = await getUserTenantRole(userId, tenantId);

  if (!role) {
    throw new ForbiddenError('您沒有權限存取此租戶');
  }

  return role;
}

/**
 * 確保用戶是 admin 或 owner
 */
export async function requireAdminAccess(
  userId: string,
  tenantId: string
): Promise<void> {
  const role = await requireTenantAccess(userId, tenantId);

  if (role !== 'admin' && role !== 'owner') {
    throw new ForbiddenError('此操作需要管理員權限');
  }
}

/**
 * 確保用戶是 owner
 */
export async function requireOwnerAccess(
  userId: string,
  tenantId: string
): Promise<void> {
  const role = await requireTenantAccess(userId, tenantId);

  if (role !== 'owner') {
    throw new ForbiddenError('此操作需要擁有者權限');
  }
}

/**
 * 新增用戶到租戶
 */
export async function addUserToTenant(
  userId: string,
  tenantId: string,
  role: 'owner' | 'admin' | 'member' = 'member'
): Promise<void> {
  const { error } = await supabase
    .from('user_tenant_access')
    .upsert({
      user_id: userId,
      tenant_id: tenantId,
      role,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id,tenant_id',
    });

  if (error) throw error;
}

/**
 * 從租戶移除用戶
 */
export async function removeUserFromTenant(
  userId: string,
  tenantId: string
): Promise<void> {
  // 不能移除 owner
  const role = await getUserTenantRole(userId, tenantId);

  if (role === 'owner') {
    throw new ForbiddenError('無法移除租戶擁有者，請先轉移擁有權');
  }

  await supabase
    .from('user_tenant_access')
    .delete()
    .eq('user_id', userId)
    .eq('tenant_id', tenantId);
}
```

---

## 建立租戶時自動設定 owner

用戶建立新租戶時，要自動成為 owner：

```typescript
export async function createTenant(
  userId: string,
  data: { name: string; slug: string }
): Promise<Tenant> {
  // 用 transaction 確保一致性
  const { data: tenant, error: tenantError } = await supabase
    .from('tenants')
    .insert({
      name: data.name,
      slug: data.slug,
    })
    .select()
    .single();

  if (tenantError) throw tenantError;

  // 建立者成為 owner
  const { error: accessError } = await supabase
    .from('user_tenant_access')
    .insert({
      user_id: userId,
      tenant_id: tenant.id,
      role: 'owner',
    });

  if (accessError) {
    // rollback: 刪除剛建立的租戶
    await supabase.from('tenants').delete().eq('id', tenant.id);
    throw accessError;
  }

  return tenant;
}
```

或者用 [PostgreSQL](https://www.postgresql.org/) 的 trigger 自動處理：

```sql
CREATE OR REPLACE FUNCTION auto_add_tenant_owner()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_tenant_access (user_id, tenant_id, role)
  VALUES (auth.uid(), NEW.id, 'owner');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_tenant_created
  AFTER INSERT ON tenants
  FOR EACH ROW
  EXECUTE FUNCTION auto_add_tenant_owner();
```

---

## 租戶切換的 UX

用戶可能屬於多個租戶，需要一個切換介面：

```tsx
// components/TenantSwitcher.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';

export function TenantSwitcher({ currentTenantId }: { currentTenantId: string }) {
  const [tenants, setTenants] = useState([]);
  const router = useRouter();

  useEffect(() => {
    // 載入用戶所有的租戶
    fetch('/api/me/tenants')
      .then(res => res.json())
      .then(data => setTenants(data));
  }, []);

  const handleSwitch = (tenantSlug: string) => {
    // 切換到另一個租戶的後台
    router.push(`/${tenantSlug}/dashboard`);
  };

  return (
    <select
      value={currentTenantId}
      onChange={(e) => {
        const tenant = tenants.find(t => t.id === e.target.value);
        if (tenant) handleSwitch(tenant.slug);
      }}
    >
      {tenants.map(tenant => (
        <option key={tenant.id} value={tenant.id}>
          {tenant.name} ({tenant.role})
        </option>
      ))}
    </select>
  );
}
```

用戶選擇後，導向 `/[tenant]/dashboard`，這個路由設計在[第三篇](/posts/nextjs-multi-tenant-routing)有講。

---

繞了一大圈，核心就一句話：**權限不要綁在 user 上，要綁在「user 和 tenant 的關係」上。**

搞懂這件事之後，三層權限模型（認證、租戶歸屬、資源權限）就是自然的結論。
`user_tenant_access` 這張表是整個架構的核心，一個用戶可以屬於多個租戶，每個租戶有不同角色。

角色也不用設計太多，owner、admin、member 三個就夠。
再配合 RLS 做深度防禦——應用層判斷商業邏輯，資料庫層防止資料洩漏。

下一篇會講**租戶品牌自訂**——怎麼讓每個租戶有自己的 Logo、顏色、Favicon。
這是 SaaS 產品很重要的功能，讓客戶覺得這是「他們的」平台，不是借用別人的。

