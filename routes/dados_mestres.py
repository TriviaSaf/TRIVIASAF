import os
from flask import Blueprint, jsonify, request
from supabase import Client, create_client

dados_bp = Blueprint("dados_bp", __name__)


def _get_supabase_client() -> Client:
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")

    if not supabase_url or not supabase_key:
        raise RuntimeError("Variaveis SUPABASE_URL e SUPABASE_KEY nao configuradas.")

    return create_client(supabase_url, supabase_key)


@dados_bp.route("/locais", methods=["GET"])
def listar_locais():
    try:
        supabase = _get_supabase_client()
        result = (
            supabase.table("locais_instalacao")
            .select("*")
            .order("descricao")
            .execute()
        )
        return jsonify({"locais": result.data, "total": len(result.data)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@dados_bp.route("/equipamentos/<local_id>", methods=["GET"])
def listar_equipamentos_por_local(local_id):
    try:
        supabase = _get_supabase_client()
        result = (
            supabase.table("equipamentos")
            .select("*")
            .eq("local_instalacao_id", local_id)
            .order("descricao")
            .execute()
        )
        return jsonify({"equipamentos": result.data, "total": len(result.data)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@dados_bp.route("/sintomas/<equipamento_id>", methods=["GET"])
def listar_sintomas_por_equipamento(equipamento_id):
    try:
        supabase = _get_supabase_client()
        result = (
            supabase.table("sintomas_catalogo")
            .select("*")
            .order("descricao")
            .execute()
        )
        return jsonify({"sintomas": result.data, "total": len(result.data)}), 200
    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@dados_bp.route("/sugerir", methods=["GET"])
def sugerir():
    """Busca inteligente por equipamentos/sintomas a partir de texto livre."""
    q = (request.args.get("q") or "").strip()
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

        # 1. Busca equipamentos cujo nome corresponde ao texto
        equip_res = (
            supabase.table("equipamentos")
            .select("id, descricao, local_instalacao_id, locais_instalacao(id, descricao)")
            .ilike("descricao", pattern)
            .eq("ativo", True)
            .limit(6)
            .execute()
        )
        for e in equip_res.data:
            local = e.get("locais_instalacao") or {}
            seen_equip_ids.add(e["id"])
            sugestoes.append({
                "tipo":        "equip",
                "equip_id":    e["id"],
                "equip_nome":  e["descricao"],
                "local_id":    e.get("local_instalacao_id"),
                "local_nome":  local.get("descricao", ""),
                "sintoma_id":  None,
                "sintoma_nome": None,
            })

        # 2. Busca locais cujo nome corresponde — retorna seus equipamentos
        if len(sugestoes) < 4:
            local_res = (
                supabase.table("locais_instalacao")
                .select("id, descricao, equipamentos(id, descricao)")
                .ilike("descricao", pattern)
                .eq("ativo", True)
                .limit(4)
                .execute()
            )
            for loc in local_res.data:
                for e in (loc.get("equipamentos") or [])[:3]:
                    if e["id"] not in seen_equip_ids:
                        seen_equip_ids.add(e["id"])
                        sugestoes.append({
                            "tipo":        "equip",
                            "equip_id":    e["id"],
                            "equip_nome":  e["descricao"],
                            "local_id":    loc["id"],
                            "local_nome":  loc["descricao"],
                            "sintoma_id":  None,
                            "sintoma_nome": None,
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
            })

        return jsonify({"sugestoes": sugestoes[:8]}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
