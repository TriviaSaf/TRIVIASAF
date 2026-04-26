import os
from flask import Blueprint, jsonify, request
from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()

dados_bp = Blueprint("dados_bp", __name__)


def _get_supabase_client() -> Client:
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")

    if not supabase_url or not supabase_key:
        raise RuntimeError("Variaveis SUPABASE_URL e SUPABASE_KEY nao configuradas.")

    return create_client(supabase_url, supabase_key)


def _dist_sq(lat1, lng1, lat2, lng2):
    """Distância² em graus (suficiente para ordenação relativa dentro de uma cidade)."""
    if lat2 is None or lng2 is None:
        return None
    return (lat1 - lat2) ** 2 + (lng1 - lng2) ** 2


@dados_bp.route("/locais", methods=["GET"])
def listar_locais():
    """Lista locais de instalação ativos.
    Retorna 'id' = id_sap para compatibilidade com o seletor manual do formulário.
    """
    try:
        supabase = _get_supabase_client()
        result = (
            supabase.table("locais_instalacao")
            .select("id_sap, codigo, descricao, lat, lng")
            .eq("ativo", True)
            .order("descricao")
            .execute()
        )
        locais = [
            {
                "id":       r["id_sap"],
                "codigo":   r.get("codigo") or r.get("id_sap", ""),
                "descricao": r["descricao"],
                "lat":      r.get("lat"),
                "lng":      r.get("lng"),
            }
            for r in result.data
        ]
        return jsonify({"locais": locais, "total": len(locais)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@dados_bp.route("/equipamentos/<local_id_sap>", methods=["GET"])
def listar_equipamentos_por_local(local_id_sap):
    """Equipamentos ativos de um local. 'id' = id_sap."""
    try:
        supabase = _get_supabase_client()
        # Usa LIKE com prefixo para que selecionar um local raiz (ex.: TV11)
        # também retorne equipamentos de seus subsistemas (TV11-2, TV11-7, etc.)
        result = (
            supabase.table("equipamentos")
            .select("id_sap, codigo, descricao, grupo_catalogo")
            .like("local_id_sap", f"{local_id_sap}%")
            .eq("ativo", True)
            .order("descricao")
            .execute()
        )
        equips = [
            {
                "id":             r["id_sap"],
                "codigo":         r.get("codigo") or r.get("id_sap", ""),
                "descricao":      r["descricao"],
                "grupo_catalogo": r.get("grupo_catalogo"),
            }
            for r in result.data
        ]
        return jsonify({"equipamentos": equips, "total": len(equips)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@dados_bp.route("/sintomas/<equipamento_id_sap>", methods=["GET"])
def listar_sintomas_por_equipamento(equipamento_id_sap):
    """Retorna sintomas válidos para o tipo de equipamento (arborização SAP).

    Busca o grupo_catalogo do equipamento e filtra sintomas_catalogo pelo mesmo
    grupo (QMGRP). Ex.: escada rolante → grupo 'ME' → apenas sintomas mecânicos.
    Sem grupo_catalogo cadastrado, retorna todos os sintomas ativos.
    """
    try:
        supabase = _get_supabase_client()

        # Descobre o grupo de catálogo SAP do equipamento
        eq_res = (
            supabase.table("equipamentos")
            .select("grupo_catalogo")
            .eq("id_sap", equipamento_id_sap)
            .maybe_single()
            .execute()
        )
        grupo = (eq_res.data or {}).get("grupo_catalogo")

        sint_q = (
            supabase.table("sintomas_catalogo")
            .select("id, codigo, descricao, grupo, codigo_item")
            .eq("ativo", True)
        )
        if grupo:
            sint_q = sint_q.eq("grupo", grupo)

        result = sint_q.order("descricao").limit(200).execute()

        sintomas = [
            {
                "id":          r["id"],
                "codigo":      r.get("codigo", ""),
                "descricao":   r["descricao"],
                "grupo":       r.get("grupo"),
                "codigo_item": r.get("codigo_item"),
            }
            for r in result.data
        ]
        return jsonify({
            "sintomas":        sintomas,
            "total":           len(sintomas),
            "grupo_filtrado":  grupo,
        }), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@dados_bp.route("/sugerir", methods=["GET"])
def sugerir():
    """Busca inteligente por equipamentos/sintomas a partir de texto livre.

    Query params:
      q   — texto digitado pelo usuário (mín. 2 chars)
      lat — latitude GPS do usuário (opcional, para ordenação por proximidade)
      lng — longitude GPS do usuário (opcional)

    Quando lat/lng são fornecidos, equipamentos mais próximos aparecem primeiro.
    """
    q = (request.args.get("q") or "").strip()
    lat = request.args.get("lat", type=float)
    lng = request.args.get("lng", type=float)
    has_gps = lat is not None and lng is not None

    if len(q) < 2:
        return jsonify({"sugestoes": []}), 200

    try:
        supabase = _get_supabase_client()
    except RuntimeError:
        return jsonify({"erro": "Configuracao do Supabase ausente"}), 500

    try:
        pattern = f"%{q}%"
        sugestoes = []
        seen_equip_ids = set()

        # Com GPS buscamos mais resultados para depois ordenar por distância
        limit_equip = 30 if has_gps else 8

        # 1. Busca equipamentos pelo nome
        equip_res = (
            supabase.table("equipamentos")
            .select("id_sap, codigo, descricao, local_id_sap")
            .ilike("descricao", pattern)
            .eq("ativo", True)
            .limit(limit_equip)
            .execute()
        )

        # Coleta ids de locais para busca em lote (evita N+1)
        local_ids = list({e["local_id_sap"] for e in equip_res.data if e.get("local_id_sap")})
        locais_map = {}
        if local_ids:
            loc_batch = (
                supabase.table("locais_instalacao")
                .select("id_sap, codigo, descricao, lat, lng")
                .in_("id_sap", local_ids)
                .execute()
            )
            locais_map = {r["id_sap"]: r for r in loc_batch.data}

        for e in equip_res.data:
            local = locais_map.get(e.get("local_id_sap") or "", {})
            dist = _dist_sq(lat, lng, local.get("lat"), local.get("lng")) if has_gps else None
            seen_equip_ids.add(e["id_sap"])
            sugestoes.append({
                "tipo":        "equip",
                "equip_id":    e["id_sap"],
                "equip_nome":  e["descricao"],
                "local_id":    local.get("id_sap") or e.get("local_id_sap"),
                "local_nome":  local.get("descricao", ""),
                "sintoma_id":  None,
                "sintoma_nome": None,
                "_dist":       dist,
            })

        # 2. Busca locais pelo nome — retorna seus equipamentos
        if len(sugestoes) < 4:
            local_res = (
                supabase.table("locais_instalacao")
                .select("id_sap, codigo, descricao, lat, lng")
                .ilike("descricao", pattern)
                .eq("ativo", True)
                .limit(4)
                .execute()
            )
            for loc in local_res.data:
                dist = _dist_sq(lat, lng, loc.get("lat"), loc.get("lng")) if has_gps else None
                equips_loc = (
                    supabase.table("equipamentos")
                    .select("id_sap, descricao")
                    .eq("local_id_sap", loc["id_sap"])
                    .eq("ativo", True)
                    .limit(4)
                    .execute()
                )
                for e in equips_loc.data:
                    if e["id_sap"] not in seen_equip_ids:
                        seen_equip_ids.add(e["id_sap"])
                        sugestoes.append({
                            "tipo":        "equip",
                            "equip_id":    e["id_sap"],
                            "equip_nome":  e["descricao"],
                            "local_id":    loc["id_sap"],
                            "local_nome":  loc["descricao"],
                            "sintoma_id":  None,
                            "sintoma_nome": None,
                            "_dist":       dist,
                        })

        # 3. Busca sintomas cujo nome corresponde ao texto
        sint_res = (
            supabase.table("sintomas_catalogo")
            .select("id, descricao")
            .ilike("descricao", pattern)
            .eq("ativo", True)
            .limit(4)
            .execute()
        )
        for s in sint_res.data:
            sugestoes.append({
                "tipo":        "sintoma",
                "equip_id":    None,
                "equip_nome":  None,
                "local_id":    None,
                "local_nome":  None,
                "sintoma_id":  s["id"],
                "sintoma_nome": s["descricao"],
                "_dist":       None,
            })

        # Ordena equipamentos por proximidade GPS; sintomas sempre no final
        if has_gps:
            equip_sugs = [s for s in sugestoes if s["tipo"] == "equip"]
            other_sugs = [s for s in sugestoes if s["tipo"] != "equip"]
            equip_sugs.sort(
                key=lambda x: x["_dist"] if x["_dist"] is not None else float("inf")
            )
            sugestoes = equip_sugs[:6] + other_sugs[:2]

        # Remove campo interno de distância antes de retornar
        for s in sugestoes:
            s.pop("_dist", None)

        return jsonify({"sugestoes": sugestoes[:8]}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
