import { NextRequest, NextResponse } from "next/server";

export async function PUT(req: NextRequest) {
  return NextResponse.json(
    { error: "Not Implemented" },
    { status: 501 }
  );
}
