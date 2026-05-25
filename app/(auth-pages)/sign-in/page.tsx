"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useSignMessage, useDisconnect } from "wagmi";
import { SiweMessage } from "siwe";
import { createClient } from "@/lib/utils/supabase/client";
import { Button } from "@/components/ui/button";
import { Wallet, LogOut, Loader2, AlertCircle, ShieldCheck } from "lucide-react";
import { toast } from "sonner";

export default function SignIn() {
  const router = useRouter();
  const supabase = createClient();
  const { address, isConnected, chainId } = useAccount();
  const { signMessageAsync } = useSignMessage();
  const { disconnect } = useDisconnect();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSignIn = async () => {
    if (!address || !chainId) {
      toast.error("Please connect your wallet first.");
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Create SIWE message
      const message = new SiweMessage({
        domain: window.location.host,
        address: address,
        statement: "Sign in with Ethereum to ArcPay.",
        uri: window.location.origin,
        version: "1",
        chainId: chainId,
        nonce: Math.random().toString(36).substring(2, 11),
      });

      const preparedMessage = message.prepareMessage();
      const signature = await signMessageAsync({ message: preparedMessage });

      const response = await fetch("/api/auth/wallet-login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: preparedMessage,
          signature,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to authenticate wallet");
      }

      toast.success("Successfully authenticated with wallet!");

      // Check if user has an existing profile
      const { data: profile } = await supabase
        .from("profiles")
        .select()
        .eq("auth_user_id", data.user.id)
        .single();

      if (!profile) {
        router.push("/onboarding");
      } else {
        router.push("/dashboard");
      }
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to sign in. Please try again.");
      toast.error(err.message || "Sign in failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col w-full flex-1 p-6 justify-center">
      <div className="flex-1 flex flex-col justify-center w-full max-w-md mx-auto animate-fade-in">
        <div className="glass-card p-8 border-white/10 shadow-[0_8px_32px_rgba(0,0,0,0.3)] rounded-2xl relative overflow-hidden">
          {/* Top glow decoration */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-1 bg-gradient-to-r from-blue-500 via-primary to-purple-500 blur-sm"></div>

          <div className="mb-8 text-center">
            <div className="w-12 h-12 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center mx-auto mb-4 animate-pulse">
              <ShieldCheck className="h-6 w-6 text-primary" />
            </div>
            <h1 className="text-3xl font-extrabold tracking-tight premium-gradient-text drop-shadow-sm mb-2">
              ArcPay
            </h1>
            <p className="text-white/60 text-sm font-medium">
              Secure Web3 Payment Gateway & Wallet
            </p>
          </div>

          {error && (
            <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 text-red-400 text-sm rounded-xl flex items-start gap-3">
              <AlertCircle className="h-5 w-5 shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          <div className="flex flex-col items-center justify-center gap-6">
            {!isConnected ? (
              <div className="w-full flex flex-col items-center gap-4">
                <div className="p-4 bg-white/5 border border-white/10 rounded-2xl text-center w-full max-w-sm mb-2">
                  <Wallet className="h-8 w-8 text-white/40 mx-auto mb-2" />
                  <p className="text-sm text-white/60">
                    Connect your Ethereum or EVM-compatible wallet to get started.
                  </p>
                </div>
                <div className="rainbowkit-btn-wrapper">
                  <ConnectButton showBalance={false} chainStatus="none" />
                </div>
              </div>
            ) : (
              <div className="w-full flex flex-col gap-4">
                <div className="p-4 bg-white/5 border border-white/10 rounded-2xl flex flex-col gap-2">
                  <div className="flex items-center justify-between text-xs text-white/40">
                    <span>Connected Wallet</span>
                    <span className="flex items-center gap-1.5">
                      <span className="h-2 w-2 rounded-full bg-green-500 animate-ping"></span>
                      Active
                    </span>
                  </div>
                  <div className="font-mono text-sm text-white break-all bg-black/20 p-2.5 rounded-lg border border-white/5">
                    {address}
                  </div>
                </div>

                <Button
                  onClick={handleSignIn}
                  disabled={loading}
                  className="w-full h-14 text-base font-bold rounded-xl premium-gradient-bg border-none shadow-[0_0_20px_rgba(59,130,246,0.2)] hover:shadow-[0_0_30px_rgba(59,130,246,0.4)] transition-all duration-300 flex items-center justify-center gap-2"
                >
                  {loading ? (
                    <>
                      <Loader2 className="h-5 w-5 animate-spin" />
                      Authenticating...
                    </>
                  ) : (
                    <>
                      <ShieldCheck className="h-5 w-5" />
                      Verify & Sign In
                    </>
                  )}
                </Button>

                <Button
                  variant="outline"
                  onClick={() => disconnect()}
                  className="w-full h-12 text-sm font-medium rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 text-white flex items-center justify-center gap-2"
                >
                  <LogOut className="h-4 w-4" />
                  Disconnect Wallet
                </Button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}