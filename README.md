# 🚗 Tapa na Lata — Estética Automotiva

PWA completo de agendamento automotivo com **Supabase** (backend + banco + auth) e deploy grátis no **Vercel**.

---

## O que está incluso

| Arquivo | Descrição |
|---|---|
| `index.html` | App completo (HTML + CSS + JS em um arquivo) |
| `manifest.json` | Manifesto PWA (instalar no celular) |
| `supabase-schema.sql` | Schema completo do banco de dados |
| `README.md` | Este guia |

### Funcionalidades

**Cliente**
- Cadastro, login e recuperação de senha
- Agendamento com seleção de serviços e adicionais
- Horários disponíveis em tempo real (respeita bloqueios e já agendados)
- Acompanhamento de status com barra de progresso
- Cancelamento de agendamento
- Notificações em tempo real (Supabase Realtime)
- Edição de perfil e senha
- PWA instalável (Android e iPhone)

**Admin** *(acesso: 3 toques no logo → aba Admin)*
- Painel com estatísticas: hoje, pendentes, em serviço, faturamento do mês
- Gráfico de faturamento dos últimos 7 dias
- Lista de agendamentos com busca e filtro por status
- Atualização de status (dispara notificação ao cliente)
- Gerenciamento de serviços e adicionais (preço, duração, ativar/desativar)
- Criação de novos serviços e adicionais
- Bloqueio de datas e horários específicos
- Indicador de conexão Realtime (ponto verde no header)

---

## Passo a passo de configuração

### 1 — Criar conta e projeto no Supabase

1. Acesse **[supabase.com](https://supabase.com)** → **Start your project**
2. Crie uma organização (pode ser seu nome)
3. Clique em **New project** e preencha:
   - **Name:** `tapanalata`
   - **Database Password:** anote em local seguro
   - **Region:** `South America (São Paulo)`
4. Aguarde ~1 minuto até o projeto ficar pronto

---

### 2 — Rodar o Schema SQL

1. No painel do Supabase, clique em **SQL Editor** (menu lateral)
2. Clique em **New query**
3. Abra o arquivo `supabase-schema.sql`, copie tudo e cole no editor
4. Clique em **Run ▶**
5. Deve aparecer `Success. No rows returned` — está correto!

---

### 3 — Criar a conta Admin

1. No Supabase, vá em **Authentication → Users**
2. Clique em **Add user → Create new user**
3. Preencha:
   - **Email:** `admin@tapanalata.com`
   - **Password:** `Admin#Lata2025`
   - ✅ Marque **Auto Confirm User**
4. Clique em **Create User**
5. Copie o **UUID** do usuário criado (coluna "UID")
6. Volte em **SQL Editor**, nova query, e rode substituindo o UUID:

```sql
UPDATE public.profiles SET role = 'admin' WHERE id = 'COLE-O-UUID-AQUI';
```

---

### 4 — Pegar as credenciais da API

1. No Supabase, vá em **Settings → API**
2. Copie:
   - **Project URL** — ex: `https://xyzabc123.supabase.co`
   - **anon / public** key — a chave longa em "Project API keys"

---

### 5 — Configurar o index.html

Abra `index.html` no VSCode. Encontre estas linhas (no início do `<script>`):

```javascript
const SUPABASE_URL  = 'https://SEU-PROJETO.supabase.co';
const SUPABASE_ANON = 'sua-anon-key-aqui';
```

Substitua pelos valores do Passo 4:

```javascript
const SUPABASE_URL  = 'https://xyzabc123.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

**Salve o arquivo.**

---

### 6 — Testar localmente

```bash
# Python (já vem no Mac/Linux)
python3 -m http.server 5500

# Node.js
npx serve .
```

Acesse `http://localhost:5500`

> ⚠️ **Não abra o `index.html` diretamente** como arquivo (`file://`) — o Supabase bloqueia por CORS. Sempre use um servidor local.

**Credenciais de teste:**

| Perfil | E-mail | Senha |
|---|---|---|
| Admin | admin@tapanalata.com | Admin#Lata2025 |
| Cliente | crie pelo formulário de Cadastro | — |

---

### 7 — Deploy no Vercel (grátis, sem servidor)

#### 7.1 — Subir para o GitHub

1. Crie um repositório no **[github.com](https://github.com)** (pode ser privado)
2. Na página do repositório: **Add file → Upload files**
3. Faça upload de todos os arquivos desta pasta

#### 7.2 — Conectar no Vercel

1. Acesse **[vercel.com](https://vercel.com)** e entre com sua conta GitHub
2. Clique em **Add New → Project**
3. Selecione o repositório `tapanalata`
4. Clique em **Deploy** (sem configurar nada)
5. Em ~30 segundos seu app estará no ar em `tapanalata.vercel.app`

---

## Banco de dados — Tabelas

| Tabela | Descrição |
|---|---|
| `profiles` | Dados dos usuários (nome, telefone, role) |
| `services` | Serviços disponíveis (preço, duração, ícone) |
| `addons` | Adicionais disponíveis |
| `appointments` | Agendamentos criados pelos clientes |
| `notifications` | Notificações por usuário |
| `blocked_slots` | Datas e horários bloqueados pelo admin |

---

## Segurança (Row Level Security)

Todas as tabelas têm **RLS ativado**:
- Cliente vê e altera **somente seus próprios dados**
- Admin tem acesso a **tudo**
- Nenhuma rota está exposta sem autenticação

---

## Perguntas frequentes

**O app mostra "Configure o Supabase"**
→ Você não substituiu `SUPABASE_URL` e `SUPABASE_ANON`. Veja o Passo 5.

**"Invalid login credentials" ao entrar como admin**
→ Verifique se criou o usuário em Authentication → Users e marcou Auto Confirm (Passo 3).

**Admin entra mas aparece como cliente**
→ Você esqueceu o `UPDATE profiles SET role = 'admin'`. Rode o SQL do Passo 3, item 6.

**Erro de CORS ao abrir o arquivo direto**
→ Use sempre um servidor local (`python3 -m http.server 5500`). Nunca abra o `file://` direto.

**Horários não aparecem para agendar**
→ Todos estão ocupados ou bloqueados. Verifique em Admin → Horários Bloqueados.

**O Realtime não está funcionando**
→ O ponto no header do admin deve ficar verde. Verifique se o projeto Supabase está ativo (projetos gratuitos pausam após 1 semana sem uso — basta reativar no painel).
