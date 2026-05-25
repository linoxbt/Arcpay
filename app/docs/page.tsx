"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { 
  BookOpen, 
  ArrowLeft, 
  Key, 
  Coins, 
  Code, 
  Cpu, 
  ChevronRight,
  ShieldCheck,
  Flame,
  FileCode2
} from "lucide-react";

type DocSection = "getting-started" | "siwe" | "contracts" | "api";

export default function DocsPage() {
  const router = useRouter();
  const [activeSection, setActiveSection] = useState<DocSection>("getting-started");

  const sidebarItems = [
    { id: "getting-started", label: "Getting Started", icon: BookOpen },
    { id: "siwe", label: "SIWE Architecture", icon: Key },
    { id: "contracts", label: "Smart Contracts", icon: Coins },
    { id: "api", label: "API Reference", icon: Code },
  ];

  return (
    <div className="flex flex-col w-full min-h-screen text-white/90">
      <header className="sticky top-0 z-40 w-full border-b border-white/5 bg-background/50 backdrop-blur-md px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => router.push("/dashboard")}
            className="hover:bg-white/5 text-white/60 hover:text-white rounded-lg transition-all"
          >
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold premium-gradient-text">ArcPay Docs</span>
            <span className="text-[10px] uppercase font-mono px-2 py-0.5 bg-primary/20 border border-primary/30 rounded-full text-primary font-semibold">
              v1.0.0
            </span>
          </div>
        </div>
        <Button
          onClick={() => router.push("/sign-in")}
          className="h-10 px-4 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white transition-all text-xs font-semibold"
        >
          Launch App
        </Button>
      </header>

      <div className="flex flex-1 w-full max-w-7xl mx-auto px-4 md:px-6 py-8 gap-8">
        <aside className="hidden md:flex flex-col w-64 shrink-0 gap-2">
          <div className="px-3 mb-2 text-xs uppercase font-mono tracking-widest text-white/30 font-semibold">
            Documentation
          </div>
          {sidebarItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                onClick={() => setActiveSection(item.id as DocSection)}
                className={`flex items-center justify-between w-full px-4 py-3 rounded-xl transition-all duration-200 text-left font-medium text-sm group ${
                  activeSection === item.id
                    ? "bg-primary/10 border border-primary/20 text-white"
                    : "border border-transparent text-white/50 hover:text-white/80 hover:bg-white/5"
                }`}
              >
                <div className="flex items-center gap-3">
                  <Icon className={`h-4 w-4 ${activeSection === item.id ? "text-primary" : ""}`} />
                  <span>{item.label}</span>
                </div>
                <ChevronRight className={`h-4 w-4 opacity-0 transition-all ${activeSection === item.id ? "opacity-100 text-primary" : "group-hover:opacity-40"}`} />
              </button>
            );
          })}
        </aside>

        <main className="flex-1 min-w-0 glass-card p-6 md:p-8 border border-white/5 rounded-2xl bg-white/[0.02]">
          <div className="flex md:hidden overflow-x-auto gap-2 pb-4 mb-6 border-b border-white/5">
            {sidebarItems.map((item) => (
              <button
                key={item.id}
                onClick={() => setActiveSection(item.id as DocSection)}
                className={`whitespace-nowrap px-4 py-2 text-xs font-semibold rounded-lg border transition-all ${
                  activeSection === item.id ? "bg-primary/10 border-primary/30 text-white" : "bg-white/5 border-white/5 text-white/40"
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>

          {activeSection === "getting-started" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                  <BookOpen className="h-6 w-6 text-primary" />
                  Getting Started
                </h2>
                <p className="text-white/60 leading-relaxed text-sm">
                  ArcPay is a high-fidelity Web3 peer-to-peer payment platform built for the Arc Network. By bridging standard Web3 wallets with a secure backend database, we enable gasless payments with absolute wallet ownership.
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 bg-white/5 border border-white/10 rounded-xl">
                  <Cpu className="h-5 w-5 text-primary mb-2" />
                  <h3 className="font-bold text-white text-sm mb-1">Arc Network Core</h3>
                  <p className="text-xs text-white/50">High-speed, low-cost execution of payments on Arc Testnet using USDC.</p>
                </div>
                <div className="p-4 bg-white/5 border border-white/10 rounded-xl">
                  <ShieldCheck className="h-5 w-5 text-purple-400 mb-2" />
                  <h3 className="font-bold text-white text-sm mb-1">SIWE Session</h3>
                  <p className="text-xs text-white/50">Gasless cryptographic authentication linking your wallet to Supabase.</p>
                </div>
              </div>
            </div>
          )}

          {activeSection === "siwe" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                  <Key className="h-6 w-6 text-primary" />
                  SIWE Identity
                </h2>
                <p className="text-white/60 leading-relaxed text-sm">
                  Instead of insecure rate-limited OTP emails, ArcPay verifies identity cryptographically on the backend using EIP-4361 standard messages and wallet signatures.
                </p>
              </div>
              <div className="p-4 bg-black/20 border border-white/5 rounded-xl text-xs text-white/60 space-y-2">
                <div>1. Frontend creates standard EIP-4361 message.</div>
                <div>2. User signs message hash.</div>
                <div>3. Backend verifies signature and signs in a deterministic Supabase user `wallet_address@arcpay.eth`.</div>
              </div>
            </div>
          )}

          {activeSection === "contracts" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                  <Coins className="h-6 w-6 text-primary" />
                  Smart Contracts
                </h2>
                <p className="text-white/60 leading-relaxed text-sm">
                  ArcPay supports zero-gas transactions on the Arc Testnet. Ensure your connected wallet is switched to the Arc network to correctly sign dashboard transactions.
                </p>
              </div>
              <div className="font-mono text-xs bg-black/40 border border-white/5 p-4 rounded-xl text-primary space-y-1">
                <div>Chain ID: 5042002</div>
                <div>RPC: https://rpc.testnet.arc.network</div>
                <div>Native: USDC (18 decimals)</div>
              </div>
            </div>
          )}

          {activeSection === "api" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                  <Code className="h-6 w-6 text-primary" />
                  API
                </h2>
                <p className="text-white/60 leading-relaxed text-sm">
                  Initialize payments and query auth parameters using our developer APIs.
                </p>
              </div>
              <div className="border border-white/5 rounded-xl bg-black/20 overflow-hidden">
                <div className="bg-white/5 px-4 py-2 border-b border-white/5 font-mono text-xs flex justify-between">
                  <span>POST /api/auth/wallet-login</span>
                  <FileCode2 className="h-4 w-4 text-white/30" />
                </div>
                <div className="p-4 font-mono text-[11px] text-white/40 space-y-1">
                  <div>{"{"}</div>
                  <div>  "message": "SIWE format...",</div>
                  <div>  "signature": "0x..."</div>
                  <div>{"}"}</div>
                </div>
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
