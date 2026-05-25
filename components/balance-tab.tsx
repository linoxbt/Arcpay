/**
 * Copyright 2026 Circle Internet Group, Inc.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { WalletInformationDialog } from "@/components/wallet-information-dialog";
import { WalletBalance } from "@/components/wallet-balance";
import { Button } from "@/components/ui/button";
import { LogOut } from "lucide-react";
import { signOutAction } from "@/app/actions";

interface Props {
  walletModels: Array<{  
    wallet_address: string;
    blockchain: string;
    chain: string;
  }>;
}

export default async function BalanceTab({ walletModels }: Props) {
  return (
    <>
      <form className="flex items-center justify-between w-full pb-6" action={signOutAction}>
        <p className="text-2xl font-bold premium-gradient-text tracking-tight">ArcPay</p>
        <Button variant="ghost" size="icon" className="hover:bg-white/10 rounded-full transition-colors">
          <LogOut className="w-5 h-5 text-white/70 hover:text-white" />
        </Button>
      </form>
      <div className="flex flex-wrap mb-6 animate-slide-up">
        {/* Wallet Card */}
        <Card className="w-full break-inside-avoid glass-card border-white/10 shadow-[0_8px_32px_rgba(0,0,0,0.2)] overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-purple-500/5 to-pink-500/10 pointer-events-none" />
          <CardHeader className="flex-row items-center border-b border-white/5 pb-4 relative z-10">
            <CardTitle className="mr-auto text-lg font-medium text-white/80">USDC Balance</CardTitle>
            <WalletInformationDialog
              wallets={walletModels}
            />
          </CardHeader>
          <CardContent className="flex flex-col gap-6 pt-6 relative z-10">
            <WalletBalance />
          </CardContent>
        </Card>
      </div>
    </>
  )
}